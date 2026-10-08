# API spec v0 (FastAPI, Python 3.12, Pydantic v2)

- Base URL: `/v1`. All routes auth-gated via Supabase JWT except `/health`.
- Mobile is the source of truth for most logs (expo-sqlite + sync). The API accepts batches with `client_id` for idempotency; the server copies the user_id from the JWT and never trusts the body for it.
- Error shape: `{"error": {"code": "snake_case", "message": "...", "field": "...?"}}`. 409 on client_id collision with the stored row returned.
- Timezone: Asia/Kolkata assumed, overridable via `profiles.timezone`.
- All numbers in SI (kg, cm, kcal). The mobile layer formats.

## Grouping

| Area | Routes |
|---|---|
| 1 Auth & profile | `/me`, `/me/consent`, `/me/export`, `/me/delete` |
| 2 Intake & onboarding | `/intake`, `/intake/preview` |
| 3 Program & case | `/program`, `/program/skeletons`, `/program/pause`, `/program/resume`, `/cases`, `/cases/{id}`, `/cases/{id}/reply`, `/plan-changes` |
| 4 Daily (Today screen) | `/today`, `/today/checkin`, `/today/short-time` |
| 5 Logs (offline sync) | `/sync/pull`, `/sync/push` + per-kind endpoints below |
| 6 Workouts | `/workouts/sessions`, `/workouts/sets`, `/workouts/pain` |
| 7 Food | `/food/search`, `/food/log`, `/food/eat-next` (A2) |
| 8 Body | `/weigh-ins`, `/measurements`, `/photos/upload-url`, `/photos`, `/photos/compare` |
| 9 Movement | `/movement/bundles`, `/movement/log` |
| 10 Progress | `/progress`, `/progress/muscles`, `/evidence` |
| 11 Coach | `/coach/messages` (SSE for stream) |
| 12 Health (F21) | `/phase`, `/phase/checkin`, `/health/documents` (post-MVP), `/health/doctor-summary` (post-MVP) |
| 13 Reminders | `/reminders`, `/reminders/{kind}` |
| 14 Entitlements | `/entitlements` (RevenueCat webhook sets, client reads) |

## Pydantic models (sketch)

```python
# shared
class Error(BaseModel):
    code: str; message: str; field: str | None = None
class Page[T](BaseModel):
    items: list[T]; next_cursor: str | None = None

# profile
class ProfileIn(BaseModel):
    sex: Literal['male','female'] | None = None
    birth_year: int | None = Field(None, ge=1920, le=2015)
    height_cm: float | None = Field(None, ge=100, le=250)
    language: Literal['hinglish','en'] = 'hinglish'
    timezone: str = 'Asia/Kolkata'
class Consent(BaseModel):
    scope: Literal['health','photos']   # explicit, DPDP
    accepted: bool
    version: str                        # policy version shown

# intake
Goal = Literal['muscle_gain','fat_loss']
Diet = Literal['veg','egg','nonveg','jain']
FoodLimit = Literal['lactose','gluten','nuts','eggs','fish','soy']
FoodControl = Literal['self','family','pg_hostel_mess','mostly_order']
class Intake(BaseModel):
    goal: Goal
    target: dict | None = None
    target_date: date | None = None
    training_days: list[int] = Field(min_length=0, max_length=7)
    session_minutes: Literal[30,45,60,75]
    location: Literal['gym','home','both']
    has_treadmill: bool = False
    day_type: Literal['desk','mixed','on_feet']
    diet: Diet
    food_limits: list[FoodLimit] = []
    cannot_eat_text: str | None = None
    food_control: FoodControl                       # A14
    meals_per_day: int = Field(ge=1, le=8)
    eat_out_per_week: Literal['0_1','2_4','5_plus']
    protein_sources: list[str] = []                 # whey only visible if listed here (A18)
    conditions: list[Literal['pcod','high_uric_acid','fatty_liver','diabetes_t2','hypertension','hypothyroid']] = []
    sleep_hours: float = Field(ge=0, le=14)
    lifting_months: Literal['lt_6','6_24','gt_24']
    current_routine_text: str | None = None
    lagging_region_id: int | None = None
    injury_text: str | None = None
    complaint_text: str                             # verbatim, golden-set

# program
class ProgramPreview(BaseModel):
    skeleton_id: UUID
    block_targets: list[BlockTargets]
    diagnosis: list[CaseSummary]                    # from Tier-3 Claude, validated
    finish_criteria: dict
    cites: list[UUID]                               # knowledge_card ids

# sync envelope
class SyncPush(BaseModel):
    workout_sessions: list[WorkoutSessionIn] = []
    set_logs: list[SetLogIn] = []
    daily_checkins: list[DailyCheckinIn] = []
    food_logs: list[FoodLogIn] = []
    weigh_ins: list[WeighInIn] = []
    measurements: list[MeasurementIn] = []
    movement_logs: list[MovementLogIn] = []
    pain_reports: list[PainReportIn] = []
    life_events: list[LifeEventIn] = []
    phase_checkins: list[PhaseCheckinIn] = []
class SyncResult(BaseModel):
    accepted: dict[str, list[UUID]]                 # client_id → server_id, per table
    rejected: list[dict]                            # {table, client_id, error}
    server_cursor: str                              # for next pull

# food log — all numbers snapshotted into the row
class FoodLogIn(BaseModel):
    client_id: UUID
    logged_at: datetime
    meal: Literal['breakfast','lunch','snack','dinner','other']
    food_id: UUID | None = None
    variant_id: UUID | None = None
    free_text: str | None = None
    place: Literal['home','dhaba','restaurant','street','chain'] | None = None
    oil: Literal['less','normal','extra'] | None = None       # oil rule C below
    unit: Literal['plate','katori','g','piece','serving']
    state: Literal['cooked','raw'] | None = None
    bone: Literal['boneless','bone'] | None = None
    size: Literal['small','medium','large'] | None = None
    qty: float = Field(gt=0)

# today
class Today(BaseModel):
    date: date
    week_of: int
    workout: PlannedSessionView | None
    food_targets: FoodTargets
    movement: MovementTargetView
    phase: PhaseView | None                         # active unwell phase short-circuits workout
```

## Routes (shapes, not full OpenAPI)

### Profile, consent, data rights
- `GET /me` → ProfileOut
- `PATCH /me` ProfileIn
- `POST /me/consent` Consent — required before `/photos/*` or `/health/*`
- `POST /me/export` → kicks off a job, returns `job_id`; result = signed-URL zip
- `POST /me/delete` → requires text confirm; hard-deletes photos + health docs, soft-deletes everything else per DPDP

### Intake and program
- `POST /intake` Intake → `{intake_id}`
- `POST /intake/preview` → ProgramPreview, no writes. Called from Diagnosis screen so the user sees the plan before accepting
- `POST /program` `{intake_id, skeleton_id}` → creates program, blocks, cases, planned_sessions, protocols. One active-or-paused program per user
- `POST /program/pause`, `POST /program/resume`
- `GET /cases?status=open|all` → list
- `GET /cases/{id}` → case + events + next_check_at
- `POST /cases/{id}/reply` `{text}` → case_event kind=user_reply; may surface a classifier label (pain, red_flag)
- `GET /plan-changes?week=` → History screen

### Daily
- `GET /today` → Today
- `POST /today/checkin` CheckinIn (readiness) → `{readiness_score, status, session_variant}`
- `GET /today/short-time?minutes=30|45|60` → session with sets cut per protection rules

### Sync (offline-first core)
- `GET /sync/pull?cursor=` → `{changes_by_table, server_cursor}` — only user's rows; sends soft-deleted rows too so the device can resolve
- `POST /sync/push` SyncPush → SyncResult. Rules:
  - server copies `user_id` from JWT, body `user_id` ignored
  - `client_id` unique per table: a row with the same client_id returns existing server_id (idempotent)
  - clock skew tolerated: `logged_at` and friends are user clock; server stamps `created_at`
  - per-row validation errors do not fail the batch

### Food
- `GET /food/search?q=&limit=20` → ranked list, trigram on `search_text`, visible rows only. Returns `foods` with best `food_variant` for the user's place preference, plus any applied allergen filters that would exclude a hit (so the UI can say "paneer removed, 3 others blocked by lactose")
- `POST /food/log` FoodLogIn → stored snapshot:
  - oil rule C: server computes `oil_adjust_kcal`: `less = -0.5 tbsp = -60 kcal`, `extra = +1 tbsp = +120 kcal`; final kcal clamped inside variant's low–high range
  - cooked/raw guard: if `food.name` is rice-like and state=cooked and qty_g < 100 → `guard_triggered='small_cooked_rice'`, kcal still saved but response flags it so the client can confirm
- `GET /food/eat-next` (A2) → `{protein_left_g, kcal_left, options:[...]}` ranked by protein-per-kcal, honoring diet + limits + food_control + budget tier (A16)

### Progress
- `GET /progress?goal=&range=2w|4w|12w` → metrics list with latest value, delta, status chip, one-line why. Uses `daily_facts` + `weekly_facts`. If data_days < 10 returns `not_enough_data=true` instead of a chart
- `GET /progress/muscles` → per muscle_region: sets_7d, status band (below/in/above), where the sets came from
- `GET /evidence?tag=` → knowledge_cards; "Source check pending" status surfaced

### Coach
- `POST /coach/messages` `{text, case_id?}` SSE
  1. classify(input) → labels; if pain/red_flag/restricted_substance → fixed safety reply, no model call
  2. build facts bundle from daily_facts + relevant cases + evidence cards tagged by case_type
  3. Claude tool-use writes response citing fact keys and card ids; Pydantic-validated
  4. on validation fail: regenerate once, else template fallback
- `GET /coach/messages?case_id=&limit=` → paginated

### Phases (F21 layer 2)
- `POST /phase` `{symptoms, red_flag?}` → opens an active phase, pauses program targets; one active phase per user
- `POST /phase/checkin` PhaseCheckinIn → computes next status (continue/stepup/doctor/doctor_now); auto-ends on 2x better
- `POST /phase/end` → user ends phase manually; weigh-ins during the phase are flagged excluded from the trend

### Movement
- `GET /movement/bundles?context=` → bundles with options
- `POST /movement/log` MovementLogIn

### Photos (F13)
- `POST /photos/upload-url` `{pose}` → `{upload_url, storage_path}` — signed URL into private bucket, path pinned to `{user_id}/{yyyy-mm-dd}/{pose}.jpg`
- `POST /photos` `{storage_path, pose, taken_at, quality}` → runs quality classifier; `low_conf_accepted` only honored on retry
- `GET /photos/compare?a=&b=&pose=` → signed URLs + observations

### Reminders & entitlements
- `GET /reminders`, `PUT /reminders/{kind}` ReminderPref
- `POST /webhooks/revenuecat` → updates entitlements (service-role)
- `GET /entitlements` → current state

## Tier split (how a route splits across layers)
```
POST /intake/preview
  Tier 1 (deterministic): BMR/TDEE, protein target, step ramp, volume targets per region,
                          plateau risk flags, 'am I on track?' projection (A12)
  Tier 2 (classifier): thin_fat flag (A3) when BMI<23 and waist>=cutoff
                        complaint intent routing from complaint_text
  Tier 3 (Claude tool use): rank hypotheses from facts, pick protocols by id, write diagnosis
                            Pydantic validates: every protocol_id exists, every citation id exists,
                            no number not already in the facts bundle
```

## Open points
- Observability: PostHog event names list (A4 log_confidence shown on dashboard; prescription adherence)
- Rate limits per route (coach is the main cost line)
- Server pagination cursors: UUIDv7 or (created_at, id) tuple — v7 is simpler
