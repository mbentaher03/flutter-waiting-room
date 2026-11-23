-- Adds optional location fields required by the offline-first workshop.
-- Existing client records remain valid and receive NULL coordinates.
alter table public.clients
  add column if not exists lat double precision,
  add column if not exists lng double precision;

notify pgrst, 'reload schema';
