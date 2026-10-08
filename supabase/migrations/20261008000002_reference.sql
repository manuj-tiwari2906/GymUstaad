-- Reference data: training catalogue, food database, knowledge cards, movement bundles.
-- Read-only to users. Seeded by scripts in supabase/seed/.

-- Training ---------------------------------------------------------------

create table public.muscle_regions (
  id            smallserial primary key,
  code          text not null unique,          -- e.g. pec_clavicular
  name          text not null,
  display_group text not null,                 -- chest, back, ... (Muscle map screen)
  side_view     text not null check (side_view in ('front', 'back'))
);

create table public.exercises (
  id            uuid primary key default gen_random_uuid(),
  parent_id     uuid references public.exercises (id),  -- display grouping; angle variants are separate rows
  name          text not null,
  angle_deg     smallint,
  equipment     text not null,
  location      text not null check (location in ('gym', 'home', 'both')),
  joint_stress  text[] not null default '{}',
  is_custom     boolean not null default false,
  created_by    uuid references auth.users (id) on delete cascade,
  created_at    timestamptz not null default now(),
  check (is_custom = (created_by is not null))
);

create table public.exercise_region_contribution (
  exercise_id   uuid not null references public.exercises (id) on delete cascade,
  region_id     smallint not null references public.muscle_regions (id),
  contribution  numeric(3, 2) not null check (contribution > 0 and contribution <= 1),
  grade         text not null check (grade in ('A', 'B', 'C')),
  source        text,
  primary key (exercise_id, region_id)
);

create table public.program_skeletons (
  id             uuid primary key default gen_random_uuid(),
  code           text not null unique,
  name           text not null,
  days_per_week  smallint not null check (days_per_week between 2 and 6),
  session_minutes smallint not null,
  location       text not null check (location in ('gym', 'home', 'both')),
  structure      jsonb not null                -- day templates; personalised by the rule engine
);

-- Food -------------------------------------------------------------------

create table public.food_sources (
  id      text primary key,                    -- S1, S2, ...
  title   text not null,
  method  text not null,
  url     text
);

-- array_to_string is only STABLE, so wrap it for use in a generated column (text[] output is deterministic).
create or replace function public.food_search_text(name text, aliases text[])
returns text
language sql
immutable
as $$ select lower(name || ' ' || array_to_string(aliases, ' ')) $$;

create table public.foods (
  id            uuid primary key default gen_random_uuid(),
  legacy_id     text unique,                   -- D001... from the seed xlsx
  name          text not null,
  aliases       text[] not null default '{}',  -- incl. Hinglish spellings
  category      text not null,
  log_mode      text not null check (log_mode in ('dish', 'weight', 'count')),
  default_unit  text not null check (default_unit in ('plate', 'katori', 'g', 'piece', 'serving')),
  food_state    text not null check (food_state in ('cooked', 'raw', 'as_served', 'cooked_dish')),
  region        text not null check (region in ('IN', 'UK_IE', 'US')),
  is_packaged   boolean not null default false,
  brand         text,
  visible       boolean not null default false, -- only reviewed, India-relevant rows are shown
  search_text   text generated always as (public.food_search_text(name, aliases)) stored
);
create index foods_search_trgm on public.foods using gin (search_text gin_trgm_ops);

create table public.food_variants (
  id             uuid primary key default gen_random_uuid(),
  food_id        uuid not null references public.foods (id) on delete cascade,
  place          text not null check (place in ('home', 'dhaba', 'restaurant', 'street', 'chain', 'takeaway')),
  serving_desc   text not null,
  serving_g      numeric(7, 1),
  per_100g       boolean not null default false,
  kcal_low       numeric(7, 1) not null,
  kcal_typ       numeric(7, 1) not null,
  kcal_high      numeric(7, 1) not null,
  fat_g_low      numeric(6, 1),
  fat_g_typ      numeric(6, 1),
  fat_g_high     numeric(6, 1),
  protein_g_typ  numeric(6, 1),
  grade          text not null check (grade in ('A', 'B', 'C')),
  source_id      text not null references public.food_sources (id),
  notes          text,
  check (kcal_low <= kcal_typ and kcal_typ <= kcal_high),
  check (fat_g_low is null or (fat_g_low <= fat_g_typ and fat_g_typ <= fat_g_high))
);
create index on public.food_variants (food_id);

-- F21 hard filters. 'check' is treated like 'yes' by the filter, so a draft tag never lets a blocked food through.
create table public.food_tags (
  food_id           uuid primary key references public.foods (id) on delete cascade,
  contains_lactose  text not null default 'check' check (contains_lactose in ('yes', 'no', 'check')),
  contains_gluten   text not null default 'check' check (contains_gluten  in ('yes', 'no', 'check')),
  contains_nuts     text not null default 'check' check (contains_nuts    in ('yes', 'no', 'check')),
  contains_egg      text not null default 'check' check (contains_egg     in ('yes', 'no', 'check')),
  contains_fish     text not null default 'check' check (contains_fish    in ('yes', 'no', 'check')),
  contains_soy      text not null default 'check' check (contains_soy     in ('yes', 'no', 'check')),
  diet_type         text not null check (diet_type in ('veg', 'egg', 'nonveg')),
  jain_ok           text not null default 'check' check (jain_ok in ('yes', 'no', 'check')),
  light_digest      text not null default 'check' check (light_digest in ('yes', 'no', 'check')),
  cost_tier         text check (cost_tier in ('low', 'med', 'high')),
  high_purine       text check (high_purine in ('yes', 'no', 'check')),
  tag_status        text not null default 'draft' check (tag_status in ('draft', 'recipe_checked'))
);

create table public.food_conversions (
  id           uuid primary key default gen_random_uuid(),
  food_id      uuid references public.foods (id) on delete cascade,
  label        text not null,                 -- e.g. 'Rice, white' while no foods row exists yet
  from_state   text not null,
  to_state     text not null,
  factor_low   numeric(5, 2),                 -- cooked g per 1 g raw
  factor_high  numeric(5, 2),
  status       text not null check (status in ('estimate', 'verified', 'needs_rule')),
  notes        text
);

create table public.household_units (
  id       uuid primary key default gen_random_uuid(),
  unit     text not null check (unit in ('katori', 'plate', 'piece', 'tbsp', 'tsp', 'glass')),
  food_id  uuid references public.foods (id) on delete cascade,  -- null = generic default
  grams    numeric(6, 1) not null,
  status   text not null check (status in ('estimate', 'verified')),
  source   text
);

create table public.food_backlog (
  id                serial primary key,
  priority          smallint not null,
  dish              text not null,
  category          text not null,
  setting           text not null,
  preferred_source  text,
  status            text not null default 'not started',
  notes             text
);

-- Knowledge + movement ---------------------------------------------------

create table public.knowledge_cards (
  id           uuid primary key default gen_random_uuid(),
  slug         text not null unique,
  title        text not null,
  claim        text not null,
  found        text not null,
  use          text not null,
  limits       text not null,
  kind         text not null,                 -- systematic review, RCT, ...
  tags         text[] not null default '{}',  -- case_type, goal; retrieval is by tag
  citations    jsonb not null,                -- [{title, authors, year, url, doi}]
  status       text not null default 'pending' check (status in ('verified', 'pending')),
  verified_at  timestamptz
);
create index knowledge_cards_tags on public.knowledge_cards using gin (tags);

create table public.protocols (
  id                  uuid primary key default gen_random_uuid(),
  code                text not null unique,
  goal_types          text[] not null,
  case_types          text[] not null,
  rung                smallint not null,
  params_schema       jsonb not null,
  bounds              jsonb not null,         -- e.g. {"max_sets_added_per_week": 4}
  knowledge_card_ids  uuid[] not null default '{}'
);

create table public.movement_bundles (
  id                 uuid primary key default gen_random_uuid(),
  name               text not null,
  context            text not null check (context in ('short_on_time', 'sits_a_lot', 'no_treadmill', 'general')),
  requires_treadmill boolean not null default false,
  joint_safe         boolean not null default true
);

create table public.movement_bundle_options (
  id         uuid primary key default gen_random_uuid(),
  bundle_id  uuid not null references public.movement_bundles (id) on delete cascade,
  label_key  text not null,                   -- string key, text lives in app string files
  params     jsonb not null                   -- minutes, sessions, speed_kmh, incline_pct
);

select public.enable_reference_rls(t) from unnest(array[
  'public.muscle_regions', 'public.exercise_region_contribution', 'public.program_skeletons',
  'public.food_sources', 'public.food_conversions', 'public.household_units', 'public.knowledge_cards',
  'public.protocols', 'public.movement_bundles', 'public.movement_bundle_options'
]::regclass[]) as t;

-- Foods: hidden rows (grade C, non-India reference rows) are never readable by users, incl. their variants and tags.
alter table public.foods enable row level security;
create policy foods_visible on public.foods for select to authenticated using (visible);
alter table public.food_variants enable row level security;
create policy food_variants_visible on public.food_variants for select to authenticated
  using (exists (select 1 from public.foods f where f.id = food_id and f.visible));
alter table public.food_tags enable row level security;
create policy food_tags_visible on public.food_tags for select to authenticated
  using (exists (select 1 from public.foods f where f.id = food_id and f.visible));

-- food_backlog is internal: RLS on, no policies, so only the service role sees it.
alter table public.food_backlog enable row level security;

-- exercises: catalogue rows are public; custom rows only to their creator.
alter table public.exercises enable row level security;
create policy exercises_read on public.exercises for select to authenticated
  using (not is_custom or created_by = auth.uid());
create policy exercises_insert_custom on public.exercises for insert to authenticated
  with check (is_custom and created_by = auth.uid());
create policy exercises_update_custom on public.exercises for update to authenticated
  using (is_custom and created_by = auth.uid()) with check (is_custom and created_by = auth.uid());
create policy exercises_delete_custom on public.exercises for delete to authenticated
  using (is_custom and created_by = auth.uid());
