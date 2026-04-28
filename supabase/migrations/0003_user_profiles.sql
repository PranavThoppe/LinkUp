-- Global user profile storage for cross-schedule defaults.
-- Profiles are keyed by client-owned UUID (linkup_profile_id).

create table if not exists public.user_profiles (
    id uuid primary key,
    display_name text not null,
    color_hex text not null,
    imessage_uuid text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create or replace function public.upsert_user_profile(
    profile_id uuid,
    display_name text,
    color_hex text,
    imessage_uuid text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if profile_id is null then
        raise exception 'profile_id is required';
    end if;

    if coalesce(btrim(display_name), '') = '' then
        raise exception 'display_name is required';
    end if;

    if color_hex !~ '^#[0-9A-Fa-f]{6}$' then
        raise exception 'color_hex must be a hex color like #1A2B3C';
    end if;

    insert into public.user_profiles (
        id,
        display_name,
        color_hex,
        imessage_uuid
    )
    values (
        profile_id,
        btrim(display_name),
        upper(color_hex),
        nullif(btrim(imessage_uuid), '')
    )
    on conflict (id) do update
    set
        display_name = excluded.display_name,
        color_hex = excluded.color_hex,
        imessage_uuid = excluded.imessage_uuid,
        updated_at = now();
end;
$$;

alter table public.user_profiles enable row level security;

drop policy if exists user_profiles_select_anon on public.user_profiles;
create policy user_profiles_select_anon
    on public.user_profiles
    for select
    to anon
    using (true);

revoke insert, update, delete on table public.user_profiles from anon;

grant execute on function public.upsert_user_profile(uuid, text, text, text) to anon;
