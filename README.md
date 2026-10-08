# GymUstaad

A knowledge-based fitness coach for Indian lifters — self-diagnosis, a personalised plan with a finish line, and follow-ups the app actually honours. Built in public.

> **Motto:** Users self-diagnose and get an individually adjusted plan for their goal without a personal trainer. The app assesses the person, finds the mistakes blocking their result, suggests a customized plan, tracks, adjusts, explains every change with data and citations, and tells them when they are done.

## Status (2026-10)

Pre-code: product thinking, schema, API spec. No app build yet.

- ✅ Product brief + architecture rules — [CLAUDE.md](CLAUDE.md)
- ✅ 33 screen mockups — [docs/mockups/](docs/mockups/)
- ✅ Research & additions (A1–A23) — [docs/research.md](docs/research.md)
- ✅ Database schema v1.1 — [docs/schema.md](docs/schema.md)
- ✅ SQL migrations + seed, running on local Supabase — [supabase/migrations/](supabase/migrations/)
- ✅ API spec v0 (FastAPI + Pydantic sketches) — [docs/api.md](docs/api.md)
- ⏳ Rule engine (Tier 1)
- ⏳ FastAPI app
- ⏳ React Native (Expo) app, Android-first
- ⏳ Knowledge cards (50–150 with citations)
- ⏳ Food DB backlog (IFCT 2017)

## Why another fitness app

From a Reddit scrape of Indian fitness subs: *"Most fitness apps track everything. None tell you why you're stuck."*

The product fixes that in three layers:
1. **Tier 1 — Rule engine.** Deterministic Python that computes every number (calories, weekly sets per muscle, plateau detection, treadmill energy, maintenance estimate).
2. **Tier 2 — Classifier.** `classify(input, schema) → label, confidence` behind an interface. Haiku or rules for MVP; swappable later.
3. **Tier 3 — Claude, on a short leash.** Ranks hypotheses and writes explanations from computed facts only. Protocol IDs and citations are validated with Pydantic. It never invents a number.

Two layers make the product:
- **Program**: a 4–6 week block plan with a finish line (e.g. "chest +2 cm and bodyweight +3 kg").
- **Case**: a specific problem (e.g. chest not growing) with an escalation ladder, test window, pass condition, and a committed follow-up date the app honours.

## Stack

- Mobile: React Native + Expo (dev client), expo-sqlite (offline-first), Android-first
- API: FastAPI, Python 3.12, Pydantic v2
- DB: Supabase Postgres with RLS on every user-owned table
- AI: Anthropic Claude (text + vision), small Postgres knowledge-card table (tag retrieval, not embeddings)
- Jobs: plain Postgres job table, polled by a worker (`FOR UPDATE SKIP LOCKED`)
- Payments: RevenueCat; Analytics: PostHog

More in [CLAUDE.md](CLAUDE.md).

## Try the schema locally

```bash
# Install Supabase CLI (one of)
brew install supabase/tap/supabase
npm install -g supabase

# Start the local stack (Docker required)
supabase start

# Apply migrations + seed happen automatically. Confirm:
psql postgres://postgres:postgres@127.0.0.1:54322/postgres \
  -c "select (select count(*) from foods), (select count(*) from food_backlog)"
# → 15 | 40
```

Visible foods will be `0` — grade A rows in the seed are UK/IE takeaway averages and grade C rows are placeholders; both are deliberately hidden from users until the Indian backlog is filled.

## What's **not** in this repo

- Raw Reddit scrapes (TOS + user privacy)
- User data of any kind
- Any `.env` with real keys

## Science anchors

"Checked" = matched against the paper abstract / publisher page. Full-PDF check happens before a number is hard-coded in the rule engine.

| Claim | Source | Status |
|---|---|---|
| Protein breakpoint 1.62 g/kg/day (95% CI 1.03–2.20) | Morton 2018, BJSM | Checked |
| 2.3–3.1 g/kg **lean body mass** for lean lifters in a cut | Helms 2014, JISSN | Checked |
| Fat loss 0.5–1%/wk; 0.7%/wk keeps lean mass | Garthe 2011, IJSNEM | Checked |
| Steps mortality benefit plateau 6–8k (60+) / 8–10k (<60) | Paluch 2022, Lancet PH | Checked |
| ICMR-NIN 2024 advises against protein supplements for healthy adults | ICMR-NIN | News coverage only, primary PDF pending |
| Indian waist cut-offs 90 cm M / 80 cm F | IDF South Asian | Checked |

Full list and limits in [docs/research.md](docs/research.md).

## License

MIT — see [LICENSE](LICENSE).
