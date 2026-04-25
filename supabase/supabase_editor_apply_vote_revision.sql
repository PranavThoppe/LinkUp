-- Run this in Supabase SQL Editor if you already applied an older schema.
-- Idempotent: safe to run multiple times.
-- Applies:
--   • vote_revision column (if missing from older deployments)
--   • Fixed submit_payload: no more delete-votes-on-write (concurrent-safe),
--     schedule revision guard tightened from >= to >, early return removed.

alter table public.votes add column if not exists vote_revision bigint not null default 0;

create or replace function public.submit_payload(payload jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_schedule jsonb;
    v_schedule_id uuid;
    v_revision bigint;
    v_last_writer_id text;
begin
    if payload is null then
        raise exception 'payload cannot be null';
    end if;

    v_schedule := payload -> 'schedule';
    if v_schedule is null then
        raise exception 'payload.schedule is required';
    end if;

    v_schedule_id := (v_schedule ->> 'id')::uuid;
    v_revision := coalesce((payload ->> 'revision')::bigint, 0);
    v_last_writer_id := coalesce(payload ->> 'lastWriterId', '');

    insert into public.schedules (
        id,
        version,
        creator_id,
        mode,
        title,
        months,
        week_range,
        specific_dates,
        eligible_date_range,
        eligible_specific_dates,
        created_at,
        updated_at,
        is_active,
        revision,
        last_writer_id
    )
    values (
        v_schedule_id,
        coalesce((payload ->> 'version')::integer, 1),
        v_schedule ->> 'creatorId',
        v_schedule ->> 'mode',
        v_schedule ->> 'title',
        v_schedule -> 'months',
        v_schedule -> 'weekRange',
        v_schedule -> 'specificDates',
        v_schedule -> 'eligibleDateRange',
        v_schedule -> 'eligibleSpecificDates',
        (v_schedule ->> 'createdAt')::timestamptz,
        (v_schedule ->> 'updatedAt')::timestamptz,
        coalesce((v_schedule ->> 'isActive')::boolean, true),
        v_revision,
        v_last_writer_id
    )
    on conflict (id) do update
    set
        version = excluded.version,
        creator_id = excluded.creator_id,
        mode = excluded.mode,
        title = excluded.title,
        months = excluded.months,
        week_range = excluded.week_range,
        specific_dates = excluded.specific_dates,
        eligible_date_range = excluded.eligible_date_range,
        eligible_specific_dates = excluded.eligible_specific_dates,
        created_at = excluded.created_at,
        updated_at = excluded.updated_at,
        is_active = excluded.is_active,
        revision = excluded.revision,
        last_writer_id = excluded.last_writer_id
    where excluded.revision > schedules.revision;

    insert into public.participants (
        schedule_id,
        imessage_uuid,
        initial,
        color,
        name,
        created_at,
        updated_at
    )
    select
        v_schedule_id,
        participant.item ->> 'id',
        participant.item ->> 'initial',
        participant.item ->> 'color',
        participant.item ->> 'name',
        now(),
        now()
    from jsonb_array_elements(coalesce(payload -> 'participants', '[]'::jsonb)) as participant(item)
    where coalesce(participant.item ->> 'id', '') <> ''
    on conflict (schedule_id, imessage_uuid) do update
    set
        initial = excluded.initial,
        color = excluded.color,
        name = excluded.name,
        updated_at = now();

    insert into public.votes as v (
        vote_id,
        schedule_id,
        participant_imessage_uuid,
        sender_initial,
        sender_color,
        dates,
        slots,
        hours,
        updated_at,
        vote_revision
    )
    select
        (incoming_vote.item ->> 'id')::uuid,
        v_schedule_id,
        incoming_vote.item ->> 'senderId',
        incoming_vote.item ->> 'senderInitial',
        incoming_vote.item ->> 'senderColor',
        coalesce(incoming_vote.item -> 'dates', '[]'::jsonb),
        case
            when jsonb_typeof(incoming_vote.item -> 'slots') = 'array' then incoming_vote.item -> 'slots'
            else null
        end,
        case
            when jsonb_typeof(incoming_vote.item -> 'hours') = 'array' then incoming_vote.item -> 'hours'
            else null
        end,
        (incoming_vote.item ->> 'updatedAt')::timestamptz,
        coalesce((incoming_vote.item ->> 'voteRevision')::bigint, 0)
    from jsonb_array_elements(coalesce(payload -> 'votes', '[]'::jsonb)) as incoming_vote(item)
    where coalesce(incoming_vote.item ->> 'senderId', '') <> ''
      and exists (
          select 1
          from public.participants participant
          where participant.schedule_id = v_schedule_id
            and participant.imessage_uuid = incoming_vote.item ->> 'senderId'
      )
    on conflict (schedule_id, participant_imessage_uuid) do update
    set
        vote_id = excluded.vote_id,
        sender_initial = excluded.sender_initial,
        sender_color = excluded.sender_color,
        dates = excluded.dates,
        slots = excluded.slots,
        hours = excluded.hours,
        updated_at = excluded.updated_at,
        vote_revision = excluded.vote_revision
    where excluded.vote_revision > v.vote_revision;
end;
$$;

grant execute on function public.submit_payload(jsonb) to anon;
