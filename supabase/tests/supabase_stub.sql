-- Minimal stand-ins for the Supabase-managed schemas (auth, storage) and roles, so the
-- migrations can be checked on a plain Postgres in CI without running the full Supabase stack.
create role authenticated nologin;
create role anon nologin;
create role service_role nologin bypassrls;

create schema auth;
create table auth.users (id uuid primary key);
create function auth.uid() returns uuid language sql stable
  as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;

create schema storage;
create table storage.buckets (id text primary key, name text, public boolean);
create table storage.objects (id uuid primary key default gen_random_uuid(), bucket_id text, name text);
alter table storage.objects enable row level security;
create function storage.foldername(name text) returns text[] language sql immutable
  as $$ select string_to_array(name, '/') $$;

grant usage on schema public, auth, storage to authenticated;
