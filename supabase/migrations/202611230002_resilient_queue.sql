-- Workshop 6 database setup.
-- public.clients.id is UUID. Flutter keeps UUID values as strings in Dart and
-- sends those strings through PostgREST, which parses p_id as PostgreSQL UUID.
-- Existing created_at values are ISO-8601 timestamps.

alter table public.clients
  add column if not exists lat double precision,
  add column if not exists lng double precision,
  add column if not exists location_accuracy_m double precision,
  add column if not exists location_captured_at timestamptz,
  add column if not exists queue_number bigint;

-- Make legacy ISO-8601 text timestamps a real timestamp for stable ordering.
alter table public.clients
  alter column created_at type timestamptz
  using nullif(created_at::text, '')::timestamptz;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'clients_valid_latitude') then
    alter table public.clients add constraint clients_valid_latitude
      check (lat is null or lat between -90 and 90);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'clients_valid_longitude') then
    alter table public.clients add constraint clients_valid_longitude
      check (lng is null or lng between -180 and 180);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'clients_valid_accuracy') then
    alter table public.clients add constraint clients_valid_accuracy
      check (location_accuracy_m is null or location_accuracy_m >= 0);
  end if;
end;
$$;

create sequence if not exists public.clients_queue_number_seq;
with numbered as (
  select id,
         row_number() over (order by created_at asc, id asc)
           + (select coalesce(max(queue_number), 0) from public.clients) as assigned
  from public.clients
  where queue_number is null
)
update public.clients
set queue_number = numbered.assigned
from numbered
where public.clients.id = numbered.id;
select setval(
  'public.clients_queue_number_seq',
  coalesce((select max(queue_number) from public.clients), 1),
  exists(select 1 from public.clients where queue_number is not null)
);
alter table public.clients
  alter column queue_number set default nextval('public.clients_queue_number_seq');
alter table public.clients alter column queue_number set not null;
create unique index if not exists clients_queue_number_unique
  on public.clients(queue_number);

-- Idempotent registration: retrying the same local UUID returns its original
-- queue number instead of creating a second official queue entry.
-- Remove the earlier text-parameter version if that migration was applied.
drop function if exists public.register_queue_client(
  text, text, double precision, double precision, double precision,
  timestamptz, timestamptz
);

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
  if p_id is null then
    raise exception 'A registration id is required';
  end if;
  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'A client name is required';
  end if;

  insert into public.clients (
    id, name, lat, lng, location_accuracy_m,
    location_captured_at, created_at, queue_number
  ) values (
    p_id, trim(p_name), p_lat, p_lng, p_accuracy,
    p_location_captured_at, coalesce(p_created_at, now()),
    nextval('public.clients_queue_number_seq')
  )
  on conflict (id) do update set
    name = excluded.name,
    lat = coalesce(excluded.lat, clients.lat),
    lng = coalesce(excluded.lng, clients.lng),
    location_accuracy_m = coalesce(excluded.location_accuracy_m, clients.location_accuracy_m),
    location_captured_at = coalesce(excluded.location_captured_at, clients.location_captured_at)
  returning queue_number into assigned_number;

  return assigned_number;
end;
$$;

-- The waiting queue API exposes names and queue order, not precise coordinates.
alter table public.clients enable row level security;
revoke all on public.clients from anon, authenticated;
revoke select (lat, lng, location_accuracy_m, location_captured_at)
  on public.clients from anon, authenticated;
grant select (id, name, created_at, queue_number)
  on public.clients to anon, authenticated;
grant execute on function public.register_queue_client(
  uuid, text, double precision, double precision, double precision,
  timestamptz, timestamptz
) to anon, authenticated;
revoke all on function public.register_queue_client(
  uuid, text, double precision, double precision, double precision,
  timestamptz, timestamptz
) from public;

-- Broadcast an allowlist of public queue fields, never location coordinates.
create or replace function public.broadcast_waiting_queue_change()
returns trigger
language plpgsql
security definer
set search_path = public, realtime
as $$
begin
  if tg_op = 'DELETE' then
    perform realtime.send(
      jsonb_build_object('id', old.id),
      'queue_delete', 'waiting-room', false
    );
    return old;
  end if;

  perform realtime.send(
    jsonb_build_object(
      'id', new.id,
      'name', new.name,
      'created_at', new.created_at,
      'queue_number', new.queue_number
    ),
    'queue_insert', 'waiting-room', false
  );
  return new;
end;
$$;

drop trigger if exists clients_waiting_queue_broadcast on public.clients;
create trigger clients_waiting_queue_broadcast
  after insert or update or delete on public.clients
  for each row execute function public.broadcast_waiting_queue_change();

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'clients'
      and policyname = 'clients_public_queue_read'
  ) then
    create policy clients_public_queue_read on public.clients
      for select to anon, authenticated using (true);
  end if;
end;
$$;

notify pgrst, 'reload schema';
