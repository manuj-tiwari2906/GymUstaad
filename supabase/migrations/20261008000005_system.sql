-- Rule-engine output, jobs, reminders, entitlements, health documents (post-MVP), storage.

-- Tier 1 output. Claude only ever sees these, never raw logs. Written by the API (service role).
create table public.daily_facts (
  user_id      uuid not null references auth.users (id) on delete cascade,
  date         date not null,
  facts        jsonb not null,               -- weight_trend, intake avg, log_confidence, protein_g_per_kg, sets_per_region_7d, ...
  computed_by  text not null,
  computed_at  timestamptz not null default now(),
  primary key (user_id, date)
);

create table public.weekly_facts (
  user_id                  uuid not null references auth.users (id) on delete cascade,
  week_start               date not null,
  maintenance_kcal_est     numeric(6, 0),
  maintenance_confidence   numeric(3, 2),
  rate_pct_per_week        numeric(5, 2),
  facts                    jsonb not null,     -- adherence counts, on_track verdict, ...
  computed_by              text not null,
  computed_at              timestamptz not null default now(),
  primary key (user_id, week_start)
);

-- Durable follow-up queue, polled by a worker (FOR UPDATE SKIP LOCKED).
create table public.jobs (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid references auth.users (id) on delete cascade,
  kind              text not null,
  payload           jsonb not null default '{}',
  run_at            timestamptz not null,
  status            text not null default 'queued' check (status in ('queued', 'running', 'done', 'failed', 'cancelled')),
  attempts          smallint not null default 0,
  last_error        text,
  locked_at         timestamptz,
  user_can_disable  boolean not null default true,   -- committed case follow-ups are false
  created_at        timestamptz not null default now()
);
create index jobs_due on public.jobs (run_at) where status = 'queued';

create table public.reminder_prefs (
  user_id      uuid not null references auth.users (id) on delete cascade,
  kind         text not null check (kind in ('workout', 'meals', 'walks', 'weigh_in', 'tape')),
  enabled      boolean not null default true,
  time_local   time,
  quiet_start  time not null default '22:00',
  quiet_end    time not null default '07:00',
  primary key (user_id, kind)
);

create table public.entitlements (
  user_id       uuid primary key references auth.users (id) on delete cascade,
  product       text,
  active_until  timestamptz,
  source        text not null default 'revenuecat',
  updated_at    timestamptz not null default now()
);

-- F21 layer 3 (post-MVP). Schema only; nothing writes here in MVP.
create table public.health_documents (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  kind          text not null check (kind in ('blood_report')),
  storage_path  text not null,
  consent_at    timestamptz not null,
  uploaded_at   timestamptz not null default now()
);

create table public.lab_values (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references auth.users (id) on delete cascade,
  document_id        uuid not null references public.health_documents (id) on delete cascade,
  analyte_code       text not null,
  value              numeric,
  unit               text,
  lab_low            numeric,
  lab_high           numeric,
  read_confidence    numeric(3, 2),
  user_confirmed_at  timestamptz,
  -- Set by rules only after the user confirms; unclear values stay unknown.
  status             text not null default 'unknown' check (status in ('low', 'in_range', 'high', 'unknown')),
  check (status = 'unknown' or user_confirmed_at is not null)
);

create table public.doctor_summaries (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references auth.users (id) on delete cascade,
  included_sections  jsonb not null,
  pdf_path           text,
  generated_at       timestamptz not null default now()
);

-- Users can read facts but never write them.
alter table public.daily_facts enable row level security;
create policy owner_select on public.daily_facts for select to authenticated using (user_id = auth.uid());
alter table public.weekly_facts enable row level security;
create policy owner_select on public.weekly_facts for select to authenticated using (user_id = auth.uid());
alter table public.entitlements enable row level security;
create policy owner_select on public.entitlements for select to authenticated using (user_id = auth.uid());

-- Jobs: users may see their own follow-ups and cancel only the ones they are allowed to.
alter table public.jobs enable row level security;
create policy owner_select on public.jobs for select to authenticated using (user_id = auth.uid());
create policy owner_cancel on public.jobs for update to authenticated
  using (user_id = auth.uid() and user_can_disable)
  with check (user_id = auth.uid() and user_can_disable and status = 'cancelled');

select public.enable_owner_rls(t) from unnest(array[
  'public.reminder_prefs', 'public.health_documents', 'public.lab_values', 'public.doctor_summaries'
]::regclass[]) as t;

-- Private storage buckets; path must start with the owner's user id.
insert into storage.buckets (id, name, public)
values ('progress-photos', 'progress-photos', false), ('health-documents', 'health-documents', false)
on conflict (id) do nothing;

create policy own_files_read on storage.objects for select to authenticated
  using (bucket_id in ('progress-photos', 'health-documents') and (storage.foldername(name))[1] = auth.uid()::text);
create policy own_files_write on storage.objects for insert to authenticated
  with check (bucket_id in ('progress-photos', 'health-documents') and (storage.foldername(name))[1] = auth.uid()::text);
create policy own_files_delete on storage.objects for delete to authenticated
  using (bucket_id in ('progress-photos', 'health-documents') and (storage.foldername(name))[1] = auth.uid()::text);
