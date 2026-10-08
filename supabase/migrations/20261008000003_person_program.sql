-- Person, intake, program layer and cases.

create table public.profiles (
  user_id              uuid primary key references auth.users (id) on delete cascade,
  sex                  text check (sex in ('male', 'female')),
  birth_year           smallint check (birth_year between 1920 and 2015),
  height_cm            numeric(5, 1) check (height_cm between 100 and 250),
  units                text not null default 'metric' check (units in ('metric')),
  timezone             text not null default 'Asia/Kolkata',
  language             text not null default 'hinglish' check (language in ('hinglish', 'en')),
  consent_health_at    timestamptz,           -- DPDP: explicit consent before any health data
  consent_photos_at    timestamptz,
  onboarding_done_at   timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create table public.intakes (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null references auth.users (id) on delete cascade,
  client_id             uuid unique,
  goal                  text not null check (goal in ('muscle_gain', 'fat_loss')),
  target                jsonb,                -- e.g. {"chest_cm": 2, "weight_kg": 3}
  target_date           date,
  training_days         smallint[] not null default '{}',   -- 1 = Mon ... 7 = Sun
  session_minutes       smallint check (session_minutes in (30, 45, 60, 75)),
  location              text check (location in ('gym', 'home', 'both')),
  has_treadmill         boolean not null default false,
  day_type              text check (day_type in ('desk', 'mixed', 'on_feet')),
  diet                  text not null check (diet in ('veg', 'egg', 'nonveg', 'jain')),
  food_limits           text[] not null default '{}'
                        check (food_limits <@ array['lactose', 'gluten', 'nuts', 'eggs', 'fish', 'soy']),
  cannot_eat_text       text,
  food_control          text check (food_control in ('self', 'family', 'pg_hostel_mess', 'mostly_order')),
  -- A21: user-declared conditions, never a diagnosis; app changes only its own display and targets.
  conditions            text[] not null default '{}'
                        check (conditions <@ array['pcod', 'high_uric_acid', 'fatty_liver', 'diabetes_t2', 'hypertension', 'hypothyroid']),
  meals_per_day         smallint check (meals_per_day between 1 and 8),
  eat_out_per_week      text check (eat_out_per_week in ('0_1', '2_4', '5_plus')),
  protein_sources       text[] not null default '{}',
  sleep_hours           numeric(3, 1) check (sleep_hours between 0 and 14),
  lifting_months        text check (lifting_months in ('lt_6', '6_24', 'gt_24')),
  current_routine_text  text,
  lagging_region_id     smallint references public.muscle_regions (id),
  injury_text           text,
  complaint_text        text,                 -- verbatim; golden-set material
  baseline_steps        integer,
  flags                 jsonb not null default '{}',  -- e.g. {"thin_fat": true}, set by rule engine
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  deleted_at            timestamptz
);
create index on public.intakes (user_id, created_at desc);

create table public.programs (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users (id) on delete cascade,
  intake_id        uuid not null references public.intakes (id),
  skeleton_id      uuid references public.program_skeletons (id),
  goal             text not null check (goal in ('muscle_gain', 'fat_loss', 'maintenance')),
  status           text not null default 'active' check (status in ('active', 'paused', 'done', 'abandoned')),
  finish_criteria  jsonb not null,
  finish_pct       numeric(5, 2),
  finish_summary   jsonb,
  started_on       date not null,
  finished_at      timestamptz,
  computed_by      text,                       -- rule engine version
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
-- At most one active or paused program per user.
create unique index programs_one_live on public.programs (user_id) where status in ('active', 'paused');

create table public.program_blocks (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  program_id   uuid not null references public.programs (id) on delete cascade,
  idx          smallint not null,
  start_date   date not null,
  end_date     date not null,
  deload_week  smallint,
  targets      jsonb not null,                 -- kcal range, protein_g, sets per region, step target
  computed_by  text not null,
  unique (program_id, idx),
  check (end_date > start_date)
);

create table public.planned_sessions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  block_id    uuid not null references public.program_blocks (id) on delete cascade,
  date        date not null,
  title_key   text not null,
  variant     text not null default 'full' check (variant in ('full', '45', '30', 'light')),
  moved_from  date
);
create index on public.planned_sessions (user_id, date);

create table public.planned_exercises (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references auth.users (id) on delete cascade,
  planned_session_id  uuid not null references public.planned_sessions (id) on delete cascade,
  position            smallint not null,
  exercise_id         uuid not null references public.exercises (id),
  sets                smallint not null check (sets between 0 and 10),
  rep_low             smallint not null,
  rep_high            smallint not null,
  target_rir          smallint check (target_rir between 0 and 5),
  suggested_load_kg   numeric(6, 2),
  protected           boolean not null default false,  -- open-case muscle: cut last
  check (rep_low <= rep_high)
);

create table public.cases (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users (id) on delete cascade,
  program_id      uuid references public.programs (id),
  case_type       text not null,
  status          text not null default 'open'
                  check (status in ('open', 'testing', 'passed', 'failed', 'escalated', 'closed')),
  current_rung    smallint not null default 1,
  success_metric  jsonb not null,              -- validated by Pydantic on the way in
  signals         jsonb not null,              -- which signals agreed, with confidence
  confidence      numeric(3, 2) check (confidence between 0 and 1),
  next_check_at   timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index on public.cases (user_id, status);

-- Append-only history. Users may read and add (e.g. their replies); nobody updates or deletes.
create table public.case_events (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  case_id      uuid not null references public.cases (id) on delete cascade,
  kind         text not null check (kind in ('observation', 'intervention', 'verdict', 'user_reply')),
  protocol_id  uuid references public.protocols (id),
  payload      jsonb not null,
  at           timestamptz not null default now()
);
create index on public.case_events (case_id, at);

create table public.plan_changes (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users (id) on delete cascade,
  program_id     uuid not null references public.programs (id) on delete cascade,
  case_id        uuid references public.cases (id),
  week           smallint not null,
  type           text not null check (type in ('training', 'food', 'recovery', 'data', 'phase')),
  title          text not null,
  why            text not null,
  basis          text not null,
  result_so_far  text,
  at             timestamptz not null default now()
);

create table public.maintenance_bands (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  program_id   uuid not null references public.programs (id) on delete cascade,
  weight_low   numeric(5, 2) not null,
  weight_high  numeric(5, 2) not null,
  started_at   timestamptz not null default now(),
  check (weight_low < weight_high)
);

-- F21 layer 2: temporary recovery phase sitting on the program.
create table public.phases (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  program_id  uuid references public.programs (id),
  kind        text not null check (kind in ('unwell')),
  symptoms    text[] not null default '{}',
  status      text not null default 'active'
              check (status in ('active', 'stepping_up', 'doctor', 'doctor_now', 'ended')),
  red_flag    boolean not null default false,
  started_at  timestamptz not null default now(),
  ended_at    timestamptz
);
create unique index phases_one_live on public.phases (user_id) where status <> 'ended';

create table public.phase_checkins (
  id        uuid primary key default gen_random_uuid(),
  user_id   uuid not null references auth.users (id) on delete cascade,
  phase_id  uuid not null references public.phases (id) on delete cascade,
  client_id uuid unique,
  date      date not null,
  feel      text not null check (feel in ('better', 'same', 'worse')),
  red_flag  boolean not null default false,
  unique (phase_id, date)
);

select public.attach_updated_at(t) from unnest(array[
  'public.profiles', 'public.intakes', 'public.programs', 'public.cases'
]::regclass[]) as t;

select public.enable_owner_rls(t) from unnest(array[
  'public.profiles', 'public.intakes', 'public.programs', 'public.program_blocks',
  'public.planned_sessions', 'public.planned_exercises', 'public.cases', 'public.plan_changes',
  'public.maintenance_bands', 'public.phases', 'public.phase_checkins'
]::regclass[]) as t;

alter table public.case_events enable row level security;
create policy owner_select on public.case_events for select to authenticated using (user_id = auth.uid());
create policy owner_insert_reply on public.case_events for insert to authenticated
  with check (user_id = auth.uid() and kind = 'user_reply');
revoke update, delete on public.case_events from authenticated, anon;

-- Service role bypasses RLS, so enforce append-only with a trigger as well.
create or replace function public.case_events_append_only()
returns trigger
language plpgsql
as $$
begin
  raise exception 'case_events is append-only';
end;
$$;
create trigger case_events_no_update before update or delete on public.case_events
  for each row execute function public.case_events_append_only();
