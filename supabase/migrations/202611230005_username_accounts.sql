-- Username-only app accounts backed by Supabase Auth's email/password API.
-- The app maps usernames to a non-deliverable internal Auth address; email
-- confirmations must therefore be disabled in Supabase Auth settings.

alter table public.profiles add column if not exists username text;

with normalized as (
  select id,
         case
           when length(clean_name) >= 3 then clean_name
           else 'user_' || substr(id::text, 1, 6)
         end as base_name
  from (
    select id,
           regexp_replace(
             lower(split_part(coalesce(email, ''), '@', 1)),
             '[^a-z0-9_.-]', '', 'g'
           ) as clean_name
    from public.profiles
    where username is null
  ) names
), ranked as (
  select id, base_name,
         row_number() over (partition by base_name order by id) as duplicate_number
  from normalized
)
update public.profiles p
set username = case
  when ranked.duplicate_number = 1 then ranked.base_name
  else left(ranked.base_name, 17) || '_' || substr(ranked.id::text, 1, 6)
end
from ranked
where p.id = ranked.id;

alter table public.profiles alter column username set not null;
alter table public.profiles
  add constraint profiles_username_format
  check (username ~ '^[a-z0-9_.-]{3,24}$');
create unique index if not exists profiles_username_lower_unique
  on public.profiles (lower(username));

create table if not exists public.admin_signup_allowlist (
  username text primary key
    check (username = lower(username) and username ~ '^[a-z0-9_.-]{3,24}$'),
  created_at timestamptz not null default now()
);
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'admin_signup_allowlist'
      and column_name = 'email'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'admin_signup_allowlist'
      and column_name = 'username'
  ) then
    alter table public.admin_signup_allowlist rename column email to username;
  end if;
end;
$$;
update public.admin_signup_allowlist
set username = lower(split_part(username, '@', 1))
where position('@' in username) > 0;
alter table public.admin_signup_allowlist enable row level security;
revoke all on public.admin_signup_allowlist from public, anon, authenticated;

create or replace function public.create_waiting_room_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  signup_username text := lower(split_part(coalesce(new.email, ''), '@', 1));
  is_bootstrap_admin boolean := false;
begin
  delete from public.admin_signup_allowlist
    where username = signup_username;
  is_bootstrap_admin := found;

  insert into public.profiles (id, email, username, role, approved, rejected)
  values (
    new.id,
    coalesce(new.email, ''),
    signup_username,
    case when is_bootstrap_admin then 'admin' else 'user' end,
    is_bootstrap_admin,
    false
  )
  on conflict (id) do update set
    email = excluded.email,
    username = excluded.username,
    role = case when is_bootstrap_admin then 'admin' else public.profiles.role end,
    approved = case when is_bootstrap_admin then true else public.profiles.approved end,
    rejected = case when is_bootstrap_admin then false else public.profiles.rejected end;
  return new;
end;
$$;

notify pgrst, 'reload schema';
