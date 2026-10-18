# Review checklist

Used by the Claude review on every PR (`.github/workflows/claude-review.yml`) and by humans.
A PR that breaks a "Must" item gets "changes needed".

## Must

**Numbers and science**
- Every number the user sees is computed in `apps/api/src/engine/` (Tier 1). No numbers invented in API routes, prompts or the app.
- Every new constant lives in `engine/constants.py` with its source and a status (`checked` / `verify`). No unsourced statistics.
- Each new engine rule has a test with a hand-worked expected value (formula in a comment).
- Guardrails stay intact: calorie target never below max(floor, BMR); fat-loss rate inside 0.5–1 %/wk; "not enough data" under 10 days.

**AI layer (Tier 3)**
- Claude only receives computed facts (`daily_facts`, `weekly_facts`), never raw logs.
- Claude output is validated with Pydantic: protocol IDs and citation IDs must exist; no number that is not already in the facts.
- Pain, red-flag and restricted-substance messages get the fixed safety reply, never a model answer.

**Health (F21)**
- Never recommend medicine, supplement names or doses. Whey only appears if the user listed it as their own protein source (A18).
- Food-limit filters treat a `check` tag as blocked.
- Red flags stop plan changes and point to a doctor.

**Data and privacy**
- Every new user-owned table has `user_id`, row-level security, and (if the phone writes it) `client_id` + `deleted_at`.
- Hidden foods (`visible = false`) are never readable by users.
- No secrets, keys or real user data in the diff. Raw scraped data stays out of the repo.
- Photos and health documents stay in private buckets with paths under the owner's user id.

## Should
- One module or feature per PR; the PR description says what changed and why.
- New user-facing text goes into the app's string files (Hinglish-first), not hard-coded.
- Migrations are additive; a destructive change explains how existing data is handled.
