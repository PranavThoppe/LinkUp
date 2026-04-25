-- LinkUp mirror schema (MVP)
-- URL payload in the iMessage bubble remains the source of truth.
-- These tables are a write-through mirror for future history/analytics/web clients.
-- Each participant's vote row is owned independently; concurrent senders do not
-- clobber each other (no full-snapshot delete on each write).

create table if not exists public.schedules (
    id uuid primary key,
    version integer not null,
    creator_id text not null,
    mode text not null,
    title text,
    months jsonb,
    week_range jsonb,
    specific_dates jsonb,
    eligible_date_range jsonb,
    eligible_specific_dates jsonb,
    created_at timestamptz not null,
    updated_at timestamptz not null,
    is_active boolean not null default true,
    revision bigint not null default 0,
    last_writer_id text not null
);

create table if not exists public.participants (
    id bigserial primary key,
    schedule_id uuid not null,
    imessage_uuid text not null,
    initial text not null,
    color text not null,
    name text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint participants_schedule_fk
        foreign key (schedule_id)
        references public.schedules (id)
        on delete cascade,
    constraint participants_schedule_imessage_unique
        unique (schedule_id, imessage_uuid)
);

create table if not exists public.votes (
    vote_id uuid not null,
    schedule_id uuid not null,
    participant_imessage_uuid text not null,
    sender_initial text not null,
    sender_color text not null,
    dates jsonb not null default '[]'::jsonb,
    slots jsonb,
    hours jsonb,
    updated_at timestamptz not null,
    vote_revision bigint not null default 0,
    constraint votes_schedule_participant_pk
        primary key (schedule_id, participant_imessage_uuid),
    constraint votes_schedule_participant_fk
        foreign key (schedule_id, participant_imessage_uuid)
        references public.participants (schedule_id, imessage_uuid)
        on delete cascade
);

-- Idempotent for databases created before vote_revision existed.
alter table public.votes add column if not exists vote_revision bigint not null default 0;

create index if not exists participants_schedule_id_idx
    on public.participants (schedule_id);

create index if not exists votes_schedule_id_idx
    on public.votes (schedule_id);
-- ////////////////////////////////////////////////////////////////////////////////
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

    -- Always upsert participants regardless of whether the schedule row moved forward.
    -- A concurrent sender whose schedule revision lost the race still needs its
    -- participant row registered so the vote FK below can succeed.
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

    -- Each participant's vote row is upserted independently using vote_revision as a
    -- per-sender fence. We intentionally do NOT delete votes absent from this payload
    -- so that two users voting concurrently each preserve the other's row.
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

alter table public.schedules enable row level security;
alter table public.participants enable row level security;
alter table public.votes enable row level security;

drop policy if exists schedules_select_anon on public.schedules;
create policy schedules_select_anon
    on public.schedules
    for select
    to anon
    using (true);

drop policy if exists schedules_insert_anon on public.schedules;
create policy schedules_insert_anon
    on public.schedules
    for insert
    to anon
    with check (true);

drop policy if exists schedules_update_anon on public.schedules;
create policy schedules_update_anon
    on public.schedules
    for update
    to anon
    using (true)
    with check (true);

drop policy if exists participants_select_anon on public.participants;
create policy participants_select_anon
    on public.participants
    for select
    to anon
    using (true);

drop policy if exists votes_select_anon on public.votes;
create policy votes_select_anon
    on public.votes
    for select
    to anon
    using (true);

revoke insert, update, delete on table public.participants from anon;
revoke insert, update, delete on table public.votes from anon;

grant execute on function public.submit_payload(jsonb) to anon;
