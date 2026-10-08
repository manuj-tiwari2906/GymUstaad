-- Raw signals logged by the user (offline-first: client_id + deleted_at on every table).

create table public.workout_sessions (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references auth.users (id) on delete cascade,
  client_id           uuid unique,
  planned_session_id  uuid references public.planned_sessions (id),
  date                date not null,
  duration_min        smallint,
  rpe_session         numeric(3, 1) check (rpe_session between 1 and 10),
  variant_done        text check (variant_done in ('full', '45', '30', 'light')),
  notes               text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz
);
create index on public.workout_sessions (user_id, date);

create table public.set_logs (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references auth.users (id) on delete cascade,
  client_id          uuid unique,
  session_id         uuid not null references public.workout_sessions (id) on delete cascade,
  exercise_id        uuid not null references public.exercises (id),
  set_idx            smallint not null,
  load_kg            numeric(6, 2) not null check (load_kg >= 0),
  reps               smallint not null check (reps between 0 and 100),
  rir                smallint not null check (rir between 0 and 3),  -- 3 means "3+"; required, hard sets are the volume unit
  suggested_load_kg  numeric(6, 2),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  deleted_at         timestamptz
);
create index on public.set_logs (user_id, exercise_id);

create table public.daily_checkins (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users (id) on delete cascade,
  client_id        uuid unique,
  date             date not null,
  sleep_bucket     smallint check (sleep_bucket between 0 and 4),
  energy           smallint check (energy between 0 and 4),
  soreness         smallint check (soreness between 0 and 4),
  stress           smallint check (stress between 0 and 4),
  readiness_score  smallint,                  -- rule engine
  steps            integer check (steps >= 0),
  sleep_hours      numeric(3, 1),
  source           text not null default 'manual' check (source in ('manual', 'health_connect', 'healthkit')),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  deleted_at       timestamptz,
  unique (user_id, date)
);

create table public.food_logs (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users (id) on delete cascade,
  client_id        uuid unique,
  logged_at        timestamptz not null,
  meal             text check (meal in ('breakfast', 'lunch', 'snack', 'dinner', 'other')),
  food_id          uuid references public.foods (id),
  variant_id       uuid references public.food_variants (id),
  free_text        text,
  place            text check (place in ('home', 'dhaba', 'restaurant', 'street', 'chain')),
  oil              text check (oil in ('less', 'normal', 'extra')),
  unit             text not null check (unit in ('plate', 'katori', 'g', 'piece', 'serving')),
  state            text check (state in ('cooked', 'raw')),
  bone             text check (bone in ('boneless', 'bone')),
  size             text check (size in ('small', 'medium', 'large')),
  qty              numeric(7, 2) not null check (qty > 0),
  -- Snapshot: food DB edits never rewrite history.
  kcal_low         numeric(7, 1) not null,
  kcal_typ         numeric(7, 1) not null,
  kcal_high        numeric(7, 1) not null,
  protein_g        numeric(6, 1),
  fat_g            numeric(6, 1),
  oil_adjust_kcal  numeric(6, 1) not null default 0,  -- oil rule C: stated tbsp, clamped to range
  method           text not null check (method in ('db', 'estimate', 'manual', 'photo')),
  guard_triggered  text,                       -- e.g. 'small_cooked_rice'
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  deleted_at       timestamptz,
  check (kcal_low <= kcal_typ and kcal_typ <= kcal_high),
  check (food_id is not null or free_text is not null)
);
create index on public.food_logs (user_id, logged_at);

create table public.weigh_ins (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users (id) on delete cascade,
  client_id        uuid unique,
  measured_at      timestamptz not null,
  weight_kg        numeric(5, 2) not null check (weight_kg between 25 and 300),
  excluded_reason  text check (excluded_reason in ('unwell', 'travel', 'festival', 'user')),
  created_at       timestamptz not null default now(),
  deleted_at       timestamptz
);
create index on public.weigh_ins (user_id, measured_at);

create table public.measurements (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  client_id    uuid unique,
  measured_at  timestamptz not null,
  site         text not null check (site in ('chest', 'waist', 'hip', 'upper_arm_r', 'thigh_r')),
  value_cm     numeric(5, 1) not null check (value_cm between 10 and 250),
  created_at   timestamptz not null default now(),
  deleted_at   timestamptz
);
create index on public.measurements (user_id, site, measured_at);

-- Photos are hard-deleted on request (DPDP); no deleted_at.
create table public.photos (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references auth.users (id) on delete cascade,
  client_id          uuid unique,
  taken_at           timestamptz not null,
  pose               text not null check (pose in ('front', 'side', 'back')),
  storage_path       text not null,           -- private bucket: {user_id}/{date}/{pose}.jpg
  quality            jsonb,                   -- lighting / frame / background / pose scores
  quality_pass       boolean,
  low_conf_accepted  boolean not null default false,
  retake_of          uuid references public.photos (id) on delete set null,
  created_at         timestamptz not null default now()
);

create table public.photo_observations (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  photo_id      uuid not null references public.photos (id) on delete cascade,
  compared_to   uuid references public.photos (id) on delete cascade,
  region_id     smallint references public.muscle_regions (id),
  observation   text not null,
  confidence    numeric(3, 2) not null check (confidence between 0 and 1),
  created_at    timestamptz not null default now()
);

create table public.movement_logs (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users (id) on delete cascade,
  client_id         uuid unique,
  date              date not null,
  bundle_option_id  uuid references public.movement_bundle_options (id),
  minutes           smallint not null check (minutes > 0),
  speed_kmh         numeric(4, 1),
  incline_pct       numeric(4, 1),
  est_kcal          numeric(6, 1),            -- ACSM estimate, always shown as an estimate
  created_at        timestamptz not null default now(),
  deleted_at        timestamptz
);

create table public.pain_reports (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  client_id    uuid unique,
  session_id   uuid references public.workout_sessions (id) on delete set null,
  exercise_id  uuid references public.exercises (id),
  area         text not null check (area in ('shoulder', 'elbow', 'wrist', 'lower_back', 'knee', 'other')),
  feel         text not null check (feel in ('burn', 'sharp', 'numb')),
  action       text not null check (action in ('stop', 'swap', 'pause')),
  swapped_to   uuid references public.exercises (id),
  created_at   timestamptz not null default now()
);

create table public.life_events (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users (id) on delete cascade,
  client_id       uuid unique,
  kind            text not null check (kind in ('travel', 'festival', 'busy')),
  start_date      date not null,
  end_date        date not null,
  applied_changes jsonb not null default '{}',
  undone_at       timestamptz,
  created_at      timestamptz not null default now(),
  check (end_date >= start_date)
);

create table public.coach_messages (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references auth.users (id) on delete cascade,
  case_id            uuid references public.cases (id) on delete set null,
  role               text not null check (role in ('user', 'assistant')),
  text               text not null,
  classifier_labels  jsonb not null default '{}',   -- pain, red_flag, restricted_substance, medical_question
  cited_fact_keys    text[] not null default '{}',
  cited_card_ids     uuid[] not null default '{}',
  model              text,
  validation_status  text check (validation_status in ('ok', 'regenerated', 'template_fallback', 'safety_response')),
  created_at         timestamptz not null default now()
);
create index on public.coach_messages (user_id, created_at);

select public.attach_updated_at(t) from unnest(array[
  'public.workout_sessions', 'public.set_logs', 'public.daily_checkins', 'public.food_logs'
]::regclass[]) as t;

select public.enable_owner_rls(t) from unnest(array[
  'public.workout_sessions', 'public.set_logs', 'public.daily_checkins', 'public.food_logs',
  'public.weigh_ins', 'public.measurements', 'public.photos', 'public.photo_observations',
  'public.movement_logs', 'public.pain_reports', 'public.life_events'
]::regclass[]) as t;

-- Coach messages: users read their thread and write their own questions; assistant rows come from the API (service role).
alter table public.coach_messages enable row level security;
create policy owner_select on public.coach_messages for select to authenticated using (user_id = auth.uid());
create policy owner_insert_user on public.coach_messages for insert to authenticated
  with check (user_id = auth.uid() and role = 'user');
