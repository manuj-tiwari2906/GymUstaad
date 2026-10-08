-- Base: extensions and shared helpers.
-- Convention: user-owned tables carry user_id (denormalised, so every RLS check is one column),
-- client_id (idempotent offline sync) and deleted_at (soft delete for sync).

create extension if not exists pg_trgm;
create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Attach the updated_at trigger to a table by name.
create or replace function public.attach_updated_at(tbl regclass)
returns void
language plpgsql
as $$
begin
  execute format(
    'create trigger set_updated_at before update on %s for each row execute function public.set_updated_at()',
    tbl
  );
end;
$$;

-- Owner-only RLS: select/insert/update/delete where user_id = auth.uid().
create or replace function public.enable_owner_rls(tbl regclass)
returns void
language plpgsql
as $$
begin
  execute format('alter table %s enable row level security', tbl);
  execute format('create policy owner_select on %s for select to authenticated using (user_id = auth.uid())', tbl);
  execute format('create policy owner_insert on %s for insert to authenticated with check (user_id = auth.uid())', tbl);
  execute format('create policy owner_update on %s for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid())', tbl);
  execute format('create policy owner_delete on %s for delete to authenticated using (user_id = auth.uid())', tbl);
end;
$$;

-- Reference tables: anyone signed in can read, only service role writes.
create or replace function public.enable_reference_rls(tbl regclass)
returns void
language plpgsql
as $$
begin
  execute format('alter table %s enable row level security', tbl);
  execute format('create policy reference_read on %s for select to authenticated using (true)', tbl);
end;
$$;
