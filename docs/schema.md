# Schema draft v1.1 (for review, no SQL yet)

Sources merged: blueprint "Data model" + F21, 33 mockups, CLAUDE.md, research.md additions (A1–A19).
Changes vs v0 are marked **NEW** or **CHANGED**. v1.1 changes (F21 + Reddit round 2) are marked **v1.1**.

## Conventions
- `uuid` PKs, `created_at / updated_at timestamptz`.
- Every user-owned table: `user_id → auth.users`, RLS `user_id = auth.uid()`. Reference tables are read-only to users.
- Offline-first: user-written tables carry `client_id uuid unique` (idempotent sync) and `deleted_at` (soft delete for sync). Hard delete only for photos + account deletion (DPDP).
- Every number the rule engine writes carries `computed_by` (engine version) so a change can be traced.
- Language: all user-facing strings come from the app's string files (Hinglish-first). DB stores keys/codes, not sentences, except user free text and Claude output.

## 1. Person
| table | key columns |
|---|---|
| `profiles` | sex **NEW** (needed for BMR, missing in mockups), birth_year, height_cm, units, timezone, language (`hinglish`/`en`) **NEW**, consent_photos_at, consent_health_at **NEW** (DPDP), onboarding_done_at |
| `intakes` **CHANGED** to typed columns | goal (`muscle_gain`/`fat_loss`), target jsonb (e.g. chest +2 cm, weight 82→76), target_date, training_days smallint[] , session_minutes (30/45/60/75), location (`gym/home/both`), has_treadmill, day_type (`desk/mixed/on_feet`), diet (`veg/egg/nonveg/jain`) **v1.1**, food_limits text[] (`lactose/gluten/nuts/eggs/fish/soy`) **v1.1**, cannot_eat_text **v1.1**, food_control (`self/family/pg_hostel_mess/mostly_order`) **v1.1 A14**, meals_per_day, eat_out_per_week (`0_1/2_4/5_plus`), protein_sources text[], sleep_hours, lifting_months bucket, current_routine_text, lagging_region_id, injury_text, complaint_text (verbatim, golden-set material), flags jsonb (e.g. `thin_fat` from A3) |

## 2. Training reference (blueprint's "proprietary asset")
| table | key columns |
|---|---|
| `muscle_regions` **NEW** | ~35 rows; code (`pec_clavicular`, `pec_sternal`…), display_group (`chest`, `back`… for Muscle Map screen), side_view (front/back) |
| `exercises` **CHANGED** | name, parent_id (display grouping), angle_deg (30° and 45° incline = separate rows), equipment, location (`gym/home`), joint_stress tags text[], is_custom, created_by. MVP seed ≈ 60 |
| `exercise_region_contribution` **NEW** | exercise_id × region_id × contribution 0–1, confidence grade, source |
| `program_skeletons` **NEW** | ~8 curated templates (3-day full body … 6-day PPL); days_per_week, minutes, location |

## 3. Program + Case
| table | key columns |
|---|---|
| `programs` | intake_id, goal, status (`active/paused/done/abandoned`) **CHANGED** (+paused), skeleton_id, finish_criteria jsonb, finish_pct, finished_at, finish_summary jsonb (Goal reached screen) |
| `program_blocks` | program_id, idx, start/end_date, deload_week, targets jsonb (kcal range, protein_g, sets per region, step target) |
| `planned_sessions` **NEW** | block_id, date, title ("Push · chest focus"), variant (`full/45/30/light`) for Short-on-time + Check-in |
| `planned_exercises` **NEW** | planned_session_id, exercise_id, sets, rep_low, rep_high, target_rir, suggested_load_kg, protected bool (case muscle, cut last) |
| `cases` | program_id, case_type, status (`open/testing/passed/failed/escalated/closed`), current_rung, success_metric jsonb (Pydantic-validated), signals jsonb, confidence, next_check_at |
| `case_events` **NEW**, append-only | case_id, kind (`observation/intervention/verdict/user_reply`), payload jsonb, protocol_id, at. No UPDATE/DELETE grant |
| `protocols` **NEW** | code, goal_types[], case_types[], rung, params_schema jsonb, bounds jsonb (e.g. max +4 sets/week), knowledge_card_ids[]. Claude may only reference these IDs |
| `plan_changes` **NEW** | program_id, week, type (`training/food/recovery/data`), title, why, basis, result_so_far, case_id (feeds "Why your plan changed" + Review) |

## 4. Logs
| table | key columns |
|---|---|
| `workout_sessions` | planned_session_id, date, duration_min, rpe_session, variant_done |
| `set_logs` | session_id, exercise_id, set_idx, load_kg, reps, rir (0/1/2/3 = 3+, **required**), suggested_load_kg |
| `daily_checkins` | date unique, sleep_bucket, energy, soreness, stress (Morning check-in, 0–4 each), readiness_score, steps (from Health Connect), sleep_hours (from Health Connect), source (`manual/health_connect/healthkit`) |
| `food_logs` **CHANGED** | logged_at, meal, food_id, variant_id, place (`home/dhaba/restaurant`), oil (`less/normal/extra`), unit (`plate/katori/g/piece`), state (`cooked/raw`), bone (`boneless/bone`), size (`small/medium/large`), qty, **snapshot** kcal_low/typ/high, protein_g, fat_g, oil_adjust_kcal, method (`db/estimate/manual/photo`), guard_triggered |
| `weigh_ins` | measured_at, weight_kg, excluded_reason (`illness/travel` from life events) |
| `measurements` | measured_at, site (`chest/waist/upper_arm_r/thigh_r/hip`), value_cm |
| `photos` | taken_at, pose (`front/side/back`), storage_path (private bucket `user_id/date/pose.jpg`), quality jsonb (lighting/frame/background/pose), quality_pass, low_conf_accepted, retake_of |
| `photo_observations` | photo_id, compared_to, region_id, observation, confidence |
| `movement_logs` | date, bundle_option_id, minutes, speed_kmh, incline_pct, est_kcal (ACSM, estimate flag) |
| `pain_reports` **NEW** | session_id, exercise_id, area, feel (`burn/sharp/numb`), action (`stop/swap/pause`), swapped_to. Hard stop: pattern removed from suggestions |
| `life_events` **NEW** (A5) | kind (`travel/festival/busy`) **v1.1** (illness moved to phases), start, end, applied_changes jsonb, undone_at |
| `phases` **v1.1** (F21 layer 2) | program_id, kind (`unwell`, later others), symptoms text[], started_at, day, status (`active/stepping_up/doctor/doctor_now/ended`), red_flag bool, ended_at. Pauses protein/kcal targets; lactose etc. filters still apply |
| `phase_checkins` **v1.1** | phase_id, date, feel (`better/same/worse`), red_flag. Exit/escalation computed by rule engine; every transition also writes a `plan_changes` row |
| `maintenance_bands` **v1.1 A13** | program_id, weight_low, weight_high (user-set), started_at |
| `coach_messages` **NEW** | thread (`case_id` nullable), role, text, cited_fact_keys[], cited_card_ids[], model, validation_status |

## 5. Food reference
| table | key columns |
|---|---|
| `foods` **CHANGED** (dish level) | name, aliases text[] (trigram, incl. Hinglish spellings), category, log_mode (`dish/weight/count`), default_unit, food_state (`cooked/raw/as_served/cooked_dish`), region (`IN/UK_IE/US`), visible bool (grade C and non-IN rows hidden), is_packaged + brand **v1.1 A15** |
| `food_tags` **v1.1** (F21 hard filters) | food_id, contains_lactose / contains_gluten / contains_nuts / contains_egg / contains_fish / contains_soy (`yes/no/check`), diet_type (`veg/egg/nonveg`), jain_ok, light_digest, cost_tier (`low/med/high`, A16), high_purine (later), tag_status (`draft/recipe_checked`). Filter rule: `yes` **and** `check` are both excluded for a user with that limit, so a draft tag can never let a blocked food through |
| `food_variants` **NEW** | food_id, place (`home/dhaba/restaurant/street/chain`), serving_desc, serving_g, kcal_low/typ/high, fat_g_low/typ/high, protein_g_typ, per_100g bool, grade (A/B/C), source_id, notes. Backlog has the same dish per setting, so place lives here |
| `food_conversions` **NEW** | food_id, from_state, to_state, factor_low, factor_high, status (`estimate/verified/needs_rule`) |
| `household_units` **NEW** | unit (`katori/plate/piece/tbsp`), food_id nullable, grams, status (`estimate/verified`) |
| `food_sources` | S1…S7 |
| `food_backlog` | internal queue |

## 6. Knowledge, movement
| table | key columns |
|---|---|
| `knowledge_cards` | slug, title, claim, found, use, limits, kind (study type), tags text[] (case_type, goal), citations jsonb, status (`verified/pending`), verified_at. Feeds Evidence library |
| `movement_bundles` / `movement_bundle_options` | as v0, plus `requires_treadmill`, `joint_safe`, `context` (`short_on_time/sits_a_lot/no_treadmill`) |

## 7. Computed + system
| table | purpose |
|---|---|
| `daily_facts` | rule-engine output per user/day: weight_trend, intake avg, **log_confidence** (A4), protein g/kg, sets per region (7d), adherence, data_days. Claude sees only this |
| `weekly_facts` **NEW** | per user/week: **maintenance_kcal_est** (A1) + its confidence, rate of change %/wk, adherence counts for dashboard |
| `jobs` | kind, run_at, payload, status, attempts, locked_at, user_can_disable (committed follow-ups = false) |
| `reminder_prefs` **NEW** | kind, enabled, time, quiet_start, quiet_end |
| `entitlements` | RevenueCat mirror |
| `analytics` | not in DB: PostHog events (logging adherence, prescription adherence, check-in replies, paywall views) to replace the manual validation metrics |

## 8. Health documents (F21 layer 3, post-MVP, schema only)
| table | key columns |
|---|---|
| `health_documents` | storage_path (private), kind (`blood_report`), uploaded_at, consent_at, deleted_at (hard delete on request) |
| `lab_values` | document_id, analyte_code, value, unit, lab_low, lab_high, read_confidence, user_confirmed_at, status (`low/in_range/high/unknown`) computed by rules only after confirmation |
| `doctor_summaries` | included_sections jsonb, generated_at, pdf_path |

## 9. Coach safety (v1.1)
`coach_messages` gets `classifier_labels jsonb` (e.g. `pain`, `red_flag`, `restricted_substance` A17, `medical_question`). Any of these short-circuits Claude to a fixed, reviewed response.

## Answers to v0 open questions (my defaults, change if you disagree)
1. `daily_facts` = table (cached), recomputed on log + nightly.
2. `food_logs` = snapshot numbers.
3. `exercises` = curated 60 + user custom flag.
4. Photos = private bucket, signed URLs with short expiry.

## Deliberately not in MVP schema
Form video / pose landmarks (F11), embeddings, social, web app.
