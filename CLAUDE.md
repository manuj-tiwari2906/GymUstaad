# Fitness Coaching App — Project Brief for Claude Code

Owner: Manuj Tiwari (senior frontend/full-stack engineer; React/TS strong, FastAPI recently learned).
Conversation language: casual Hinglish is fine. Be direct, concise, no lectures.

Full blueprint (source of truth for features F1–F20):
https://claude.ai/code/artifact/95b3de03-f105-4496-b75c-21e513040a07

## Motto
Users self-diagnose and get a knowledge-based, individually adjusted plan for their goal without a personal trainer. The app assesses the person, finds the mistakes blocking their result, suggests a customized plan, tracks, adjusts, explains every change with data and citations, and tells them when they are done.

## MVP scope (locked)
- Goals: **muscle gain + fat loss**. Weight gain and recomposition come after first real users (same loop).
- Core loop: assess -> find mistakes -> plan -> customize -> track -> adjust.
- Diagnosis combines ALL signals (intake, training logs, food/protein, sleep/recovery, measurements, weight trend, photos). A verdict is stated only when several signals agree; the plan names the signals it rests on.
- Never generic output (e.g. "do 10k steps"). Always customized to the person's constraints.

## Architecture rules
1. Tier 1: deterministic Python rule engine computes ALL numbers (calories, volume, plateau detection, progression, treadmill/walking energy).
2. Tier 2: classifier behind `classify(input, schema) -> label, confidence` (Haiku or rules for MVP; Jev swappable later).
3. Tier 3: Claude (tool use) ranks hypotheses and writes explanations from computed facts. It never invents protocols or numbers. Output validated with Pydantic.
4. The reasoning model receives computed facts, never raw logs.

## AI scope for MVP
- IN: rule engine, Claude text + vision, small Postgres knowledge-card table (50–150 curated science cards with source links, retrieved by tag such as case_type, not by embeddings).
- OUT for now: RAG/vector pipeline, Jev, MediaPipe form analysis (F11). pgvector extension may stay enabled but no embedding pipeline yet.
- Food search: start with Postgres trigram/full-text.

## Stack
React Native + Expo dev client, expo-sqlite (offline-first), FastAPI (Python 3.12, Pydantic v2), Supabase Postgres + RLS, Postgres-backed job table for follow-ups, RevenueCat, PostHog.

## Key features in MVP
- Program + Case two-layer model: Program = personalised plan in 4–6 week blocks with a finish line; Case = a problem found inside a program, with escalation ladder, test windows, pass conditions, committed follow-up dates.
- F7 Clean logging: one-tap food logging (e.g. "1 plate rajma"), Indian-food-aware, restaurant dishes stored as low/typical/high ranges, not single numbers.
- F10 body measurements, F19 progress dashboard (goal-wise lead metrics, trend + one-line reason per number, adherence instead of streaks, "not enough data" under 10 days).
- F20 movement plan: bundles of equal-effect options instead of one target; ramp about +1,000 steps/week from the person's baseline; swap bundle when the user cannot do it; treadmill/incline calculator using the ACSM walking equation (shown as estimate, verified against weight trend; no incline if joint limits).
- Photo/video quality gate: instruct before capture (full even lighting, plain background, same spot/distance/pose), check after capture, ask for retake when poor, show confidence on every photo observation. Photos support, never decide alone; cross-check with tape and lift trends. MVP = week-to-week comparison plus likely-lagging-area estimates.

## Science anchors (verify before hard-coding)
Weekly sets 12–20 per muscle (Baz-Valle 2022), individualised volume (Scarpelli 2020), fat loss 0.5–1% bodyweight/week (Helms 2014; Garthe 2011 0.7%/wk), protein 2.3–3.1 g/kg of LEAN BODY MASS for lean lifters in a cut (Helms 2014). General muscle-gain protein: Morton 2018 breakpoint 1.62 g/kg/day, 95% CI 1.03–2.20. Steps: mortality benefit plateaus at 8–10k/day under 60 and 6–8k at 60+ (Paluch 2022). Sources and check status in docs/research.md.

## Food database
`fitness_food_db_seed.xlsx`: 15 dishes filled (11 lab-measured UK/IE takeaway grade A, 2 chow mein reference grade B, 2 grade C placeholders), 40 queued in Backlog. No source publishes average oil per Indian restaurant dish, so store kcal/fat ranges with a source grade. Indian home and dhaba values still need IFCT 2017 and Indian measured data.

## TODO (in order)
1. Database schema (include `movement_bundles`, `knowledge_cards`, programs, cases, logs, measurements, photos).
2. API spec (FastAPI routes + Pydantic models).
3. Screen list and wireframes (onboarding/intake, daily screen, dashboard, case view, photo capture).
4. Write 50–150 knowledge cards with citations.
5. Run the validation protocol with real users (at least 5 people, Reddit recruiting is fine).
6. Fill food DB backlog, priority 1 first.
7. Then build.

## Screens (33 mockups, sample data only)
Mockups: https://claude.ai/artifact/CYFAWaTL4qKavJP36m1KYD (phone frames 390x844). Build screens from these. Visual style: ground #F4F5F1, ink #14201E, primary teal #0E5A52, tint #E1EFEC, warning amber #FBEFD9 / #C77F0A, muted #5B6763, line #E3E6E0; Manrope font; 12-16px radii; bottom tab bar Today / Plan / Log / Progress.
Core flow: 1 Goal and basics, 2 Photo with quality check, 3 Diagnosis, 4 Program, 5 Today, 6 Clean food logging, 7 Movement plan, 8 Progress dashboard, 9 Weekly review and case.
Setup and logging: 10-12 Intake (week, food and sleep, training history), 13 Workout logging, 14 Weight and measurements, 15 Photo compare, 16 Coach chat.
Milestones and housekeeping: 17 Goal reached, 18 Pain check, 19 Settings and privacy, 20 Plans (price and free/paid split are placeholders), 21 Reminders, 22 Empty and error states (offline, not enough data, assessment failed, not enough signals).
Health constraints (see blueprint F21): 30 Intake: food limits (diet type, lactose/gluten/nuts/egg/fish/soy as hard filters; protein target unchanged, only sources swap) and 31 Not feeling well (light-food phase, daily better/same/worse check-in, step-up when better, doctor prompt for red flags or no improvement by day 3; MVP). 32 Blood report and 33 Summary for your doctor are post-MVP.
Beyond the MVP (row 4, interactive, build after launch if tests support them): 23 Morning check-in (readiness score), 24 Muscle map (weekly sets per muscle vs 12-20 band), 25 Short on time (60/45/30 min versions, protected muscle), 26 What should I eat next (protein left, home or ordering out), 27 Why your plan changed (history with reason and data), 28 Evidence library (citations; Morton 2018 protein figure still needs source check), 29 Life happens (travel, illness, festival, busy week).
Interactive in MVP set: 6 Food log (Chole bhature uses place/oil, Rice and Chicken use katori or grams with a Cooked/Raw toggle and a wrong-state guard, Roti is counted in pieces; values are placeholders until the food DB is filled) and 8 Progress dashboard.
Open items in mockups: privacy wording in Settings is a placeholder; paywall price and split are undecided; all numbers are sample.

## Working rules
- Remind about model choice: Sonnet for routine/structured work, Opus only for deep architecture reasoning.
- Do not use unverified statistics; flag "from memory" items.
- Keep outputs concise and structured.

## Food data rule: cooked vs raw
Every food has food_state (cooked, raw, as_served, cooked_dish). Countable items are logged in pieces. Rice, dal, chicken and similar default to katori; grams is advanced with a Cooked/Raw choice (default Cooked). Raw to cooked factors live in the Conversions sheet of fitness_food_db_seed.xlsx and are unverified estimates. Guard against raw weights logged as cooked.

## Health rules (F21)
- Never recommend medicine, supplement names or doses. For flagged blood values say what it may affect and tell the user to discuss it with a doctor. Food ideas are fine.
- Never diagnose. Red flags (blood in stool, high fever, cannot keep fluids down, worse or no better by day 3) stop plan changes and tell the user to see a doctor.
- Hard filters from intolerances and allergies apply everywhere food is suggested. Diet tags in the food DB are drafts until each recipe is checked.
- Blood values are read by Claude vision, confirmed by the user, and compared with the lab's own range by deterministic rules. Unclear values stay "unknown".
- Health data needs explicit consent, easy delete, and DPDP Act review plus legal review of wording before launch.
