-- Pre-authorize a trusted admin email before its first Supabase Auth signup.
-- This avoids self-approval while keeping regular signups pending.

create table if not exists public.admin_signup_allowlist (
  email text primary key,
  created_at timestamptz not null default now()
);

alter table public.admin_signup_allowlist enable row level security;
revoke all on public.admin_signup_allowlist from public, anon, authenticated;

create or replace function public.create_waiting_room_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  is_bootstrap_admin boolean := false;
begin
  if new.email is not null then
    delete from public.admin_signup_allowlist
      where lower(email) = lower(new.email);
    is_bootstrap_admin := found;
  end if;

  insert into public.profiles (id, email, role, approved, rejected)
  values (
    new.id,
    coalesce(new.email, ''),
    case when is_bootstrap_admin then 'admin' else 'user' end,
    is_bootstrap_admin,
    false
  )
  on conflict (id) do update set
    email = excluded.email,
    role = case when is_bootstrap_admin then 'admin' else public.profiles.role end,
    approved = case when is_bootstrap_admin then true else public.profiles.approved end,
    rejected = case when is_bootstrap_admin then false else public.profiles.rejected end;
  return new;
end;
$$;

notify pgrst, 'reload schema';
