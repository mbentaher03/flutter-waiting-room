-- Account approval and administrator controls for the shared waiting queue.
-- Apply after 202611230002_resilient_queue.sql.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  role text not null default 'user' check (role in ('user', 'admin')),
  approved boolean not null default false,
  rejected boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;

alter table public.clients
  add column if not exists created_by uuid references auth.users(id) on delete set null;

create or replace function public.create_waiting_room_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, role, approved, rejected)
  values (new.id, coalesce(new.email, ''), 'user', false, false)
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_waiting_room on auth.users;
create trigger on_auth_user_created_waiting_room
  after insert on auth.users
  for each row execute function public.create_waiting_room_profile();

-- Existing Supabase Auth users must also receive a pending profile row.
insert into public.profiles (id, email, role, approved, rejected)
select id, coalesce(email, ''), 'user', false, false
from auth.users
on conflict (id) do update set email = excluded.email;

create or replace function public.current_user_is_approved()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and approved = true
  );
$$;

create or replace function public.current_user_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and approved = true and role = 'admin'
  );
$$;

drop policy if exists clients_public_queue_read on public.clients;
drop policy if exists clients_approved_queue_read on public.clients;
create policy clients_approved_queue_read on public.clients
  for select to authenticated using (public.current_user_is_approved());

create policy profiles_read_self_or_admin on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.current_user_is_admin());

-- Revoke the old anonymous queue API. Approved users can read the public
-- queue fields only; location data remains private.
revoke all on public.clients from anon, authenticated;
revoke select (id, name, created_at, queue_number)
  on public.clients from anon, authenticated;
grant select (id, name, created_at, queue_number)
  on public.clients to authenticated;
revoke execute on function public.register_queue_client(
  uuid, text, double precision, double precision, double precision,
  timestamptz, timestamptz
) from anon, public;

create or replace function public.register_queue_client(
  p_id uuid,
  p_name text,
  p_lat double precision,
  p_lng double precision,
  p_accuracy double precision,
  p_location_captured_at timestamptz,
  p_created_at timestamptz
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  assigned_number bigint;
begin
  if auth.uid() is null or not public.current_user_is_approved() then
    raise exception 'An approved account is required to join the queue'
      using errcode = '42501';
  end if;
  if p_id is null or p_name is null or length(trim(p_name)) = 0 then
    raise exception 'A registration id and name are required';
  end if;

  insert into public.clients (
    id, name, lat, lng, location_accuracy_m,
    location_captured_at, created_at, queue_number, created_by
  ) values (
    p_id, trim(p_name), p_lat, p_lng, p_accuracy,
    p_location_captured_at, coalesce(p_created_at, now()),
    nextval('public.clients_queue_number_seq'), auth.uid()
  )
  on conflict (id) do update set
    name = excluded.name,
    lat = coalesce(excluded.lat, clients.lat),
    lng = coalesce(excluded.lng, clients.lng),
    location_accuracy_m = coalesce(excluded.location_accuracy_m, clients.location_accuracy_m),
    location_captured_at = coalesce(excluded.location_captured_at, clients.location_captured_at),
    created_by = coalesce(clients.created_by, auth.uid())
  where clients.created_by is null or clients.created_by = auth.uid()
  returning queue_number into assigned_number;

  if assigned_number is null then
    raise exception 'Registration id already belongs to another account';
  end if;

  return assigned_number;
end;
$$;
grant execute on function public.register_queue_client(
  uuid, text, double precision, double precision, double precision,
  timestamptz, timestamptz
) to authenticated;

create or replace function public.admin_set_user_approval(
  p_user_id uuid,
  p_approved boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.current_user_is_admin() then
    raise exception 'Administrator access required' using errcode = '42501';
  end if;
  update public.profiles
    set approved = p_approved, rejected = not p_approved
    where id = p_user_id and role <> 'admin';
  if not found then
    raise exception 'User not found or administrator approval cannot be changed';
  end if;
end;
$$;
revoke all on function public.admin_set_user_approval(uuid, boolean) from public, anon;
grant execute on function public.admin_set_user_approval(uuid, boolean) to authenticated;

create or replace function public.admin_set_user_role(
  p_user_id uuid,
  p_role text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.current_user_is_admin() then
    raise exception 'Administrator access required' using errcode = '42501';
  end if;
  if p_role not in ('user', 'admin') then
    raise exception 'Role must be user or admin';
  end if;
  if p_role = 'user' and exists (
    select 1 from public.profiles
    where id = p_user_id and role = 'admin' and approved = true
  ) and (
    select count(*) from public.profiles
    where role = 'admin' and approved = true
  ) <= 1 then
    raise exception 'At least one approved administrator must remain';
  end if;
  update public.profiles
    set role = p_role
    where id = p_user_id and approved = true;
  if not found then
    raise exception 'Approved account not found';
  end if;
end;
$$;
revoke all on function public.admin_set_user_role(uuid, text) from public, anon;
grant execute on function public.admin_set_user_role(uuid, text) to authenticated;

create or replace function public.admin_delete_queue_client(p_client_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.current_user_is_admin() then
    raise exception 'Administrator access required' using errcode = '42501';
  end if;
  delete from public.clients where id = p_client_id;
end;
$$;
revoke all on function public.admin_delete_queue_client(uuid) from public, anon;
grant execute on function public.admin_delete_queue_client(uuid) to authenticated;

create or replace function public.admin_call_next_client()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  next_id uuid;
begin
  if not public.current_user_is_admin() then
    raise exception 'Administrator access required' using errcode = '42501';
  end if;
  select id into next_id
    from public.clients
    order by queue_number asc
    limit 1
    for update;
  if next_id is not null then
    delete from public.clients where id = next_id;
  end if;
  return next_id;
end;
$$;
revoke all on function public.admin_call_next_client() from public, anon;
grant execute on function public.admin_call_next_client() to authenticated;

revoke all on function public.current_user_is_approved() from public, anon;
revoke all on function public.current_user_is_admin() from public, anon;
grant execute on function public.current_user_is_approved() to authenticated;
grant execute on function public.current_user_is_admin() to authenticated;

notify pgrst, 'reload schema';
