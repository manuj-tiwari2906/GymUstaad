# Research v1: problems, evidence, additions

Status: round 1 (free web search). Reddit blocks direct fetching, so verbatim Reddit complaints are thin here. Round 2 = Reddit scrape (see end).
"Checked" below means the figure was matched against the paper's abstract/PubMed or publisher page, not yet the full PDF. Full-PDF check happens before a number is hard-coded in the rule engine.

## 1. Problems people repeatedly report

| # | Problem | Evidence | What the app does |
|---|---|---|---|
| P1 | Vegetarian protein gap: Indian veg diets land far below lifting targets; people don't know their real intake | Recurring r/IndianFitness / r/Fitness_India theme ("is 90–110g protein enough", "review my veg diet") ([gummysearch](https://gummysearch.com/r/indianfitness), [r/Fitness_India thread](https://cal1.lr.ggtyler.dev/r/Fitness_India/comments/1gd7vk3/is_90110g_protein_enough)). ICMR-NIN 2024: avg intake ~0.66 g/kg vs RDA 0.83 g/kg ([ICMR coverage](https://thesouthfirst.com/health/icmr-releases-dietary-guidelines-for-indians-after-13-years-says-no-to-protein-supplements/)) | Protein-left planner with veg-first options (A2) |
| P2 | "Eating 1,200–1,800 and not losing weight" | Lichtman 1992 NEJM: diet-resistant subjects under-reported intake by 47% and over-reported activity by 51%; metabolism was within 5% of predicted ([PubMed 1454084](https://pubmed.ncbi.nlm.nih.gov/1454084/)) | Rung 1 of fat-loss ladder = data quality; adaptive maintenance estimate (A1) |
| P3 | Skinny-fat / "thin-fat" | South Asians carry less lean mass and more abdominal fat at the same BMI ([Wells, UCL](https://discovery-pp.ucl.ac.uk/id/eprint/10093402/8/Wells_nxaa026.pdf), [JECH](https://jech.bmj.com/content/69/12/1147)) | Intake flag routes to muscle-gain-first (A3) |
| P4 | Strength plateau for months (e.g. bench stuck 3–4 months) | r/Fitness_India, [r/Gymhelp](https://redlib.ssps.io/r/Gymhelp/comments/1kkhinb/bench_plateau) | Already core (F3 plateau, case ladder) |
| P5 | Lagging body part (upper chest) | Many generic articles, few data-driven answers | Already core (region volume, case ladder) |
| P6 | Trainers/coaches: generic plans, no explanation, poor follow-through, upsell pressure | HealthifyMe Trustpilot 2.9/5, coaching quality + support are top complaints ([Trustpilot](https://pt.trustpilot.com/review/www.healthifyme.com)); Fittr: inconsistent coach engagement after purchase ([JustUseApp](https://justuseapp.com/en/app/1332568703/fittr-health-fitness-coach/reviews)) | Committed follow-ups that always fire; no upsell pressure (A7) |
| P7 | People quit tracking apps fast | 3% of 190,000 food-journal downloads used it >1 week ([Big Think summary](https://bigthink.com/ideafeed/why-so-many-people-quit-food-logging-apps-in-the-first-week)); six abandonment reasons: effort, privacy, guilt, bad data, "learned enough", life changes ([Epstein et al., PMC5428074](https://pmc.ncbi.nlm.nih.gov/articles/PMC5428074/)) | A4, A5, A6 |

## 2. Science anchors: status after this round

| Anchor | Finding | Status |
|---|---|---|
| Protein, muscle gain | Morton 2018 (BJSM, 49 RCTs, n=1,863): no further FFM gain beyond **1.62 g/kg/day**; 95% CI **1.03–2.20** ([PubMed 28698222](https://pubmed.ncbi.nlm.nih.gov/28698222/)) | Checked. Use 1.6 g/kg as floor, up to 2.2 |
| Protein, lean lifter in a cut | Helms 2014: **2.3–3.1 g/kg of lean body mass** ([PMC4033492](https://pmc.ncbi.nlm.nih.gov/articles/PMC4033492/)) | Checked. **CLAUDE.md says "2.2–3.0 g/kg" (total body weight). Wrong unit: it is per kg lean mass.** |
| Fat loss rate | Helms 2014: 0.5–1%/week. Garthe 2011: 0.7%/wk kept/increased lean mass vs 1.4%/wk ([IJSNEM record](https://lida.sport-iat.de/ta/Record/4020442?lng=en)) | Checked |
| Steps | Paluch 2022 Lancet Public Health: mortality benefit plateaus at 6–8k (60+) and 8–10k (<60) steps/day ([DOAJ](https://doaj.org/article/c3639c468b4348958202e52793ab979d)) | Checked. Resolves "steps threshold unverified" |
| Indian waist cut-offs | ≥90 cm men, ≥80 cm women (IDF South Asian) ([Harvard summary](https://www.hsph.harvard.edu/obesity-prevention-source/waist-circumference-guidelines-for-different-ethnic-groups/)) | Checked |
| Asian BMI | Overweight 23, obesity 27.5 (WHO 2004 Lancet) ([summary](https://bioblast.at/index.php/WHO_Expert_Consultation_2004_Lancet)) | Checked. Context only, never a headline |
| ICMR on supplements | ICMR-NIN 2024 advises against protein supplements for healthy people | Checked (news coverage). Primary PDF pending |

Not used: blog posts from supplement brands (MuscleBlaze, MyProtein) for any number.

## 3. Additions (pre-approved, aligned with the motto)

| ID | Addition | Why | Scope |
|---|---|---|---|
| A1 | **Adaptive maintenance estimate**: derive real maintenance kcal from logged intake + weight trend; recalc weekly. Days with obviously incomplete logs are excluded | P2. Same idea as MacroFactor's expenditure model ([MacroFactor](https://macrofactorapp.com/?p=4961)). Blueprint F8 already wants it | MVP, rule engine |
| A2 | **"Protein left" planner (lite version of screen 26)**: home / ordering-out options ranked by protein per kcal, veg-first if user is veg | P1 is the most common Indian complaint | Promote to MVP |
| A3 | **Thin-fat flag at intake**: BMI < 23 but waist ≥ 90/80 cm → explain and start with muscle gain, not a deficit | P3 | MVP rule |
| A4 | **Log confidence per day** (complete / partial / missing) shown on dashboard; diagnosis ignores low-confidence days and says so | P7 "bad data" + P2 | MVP |
| A5 | **Life happens, lite (screen 29)**: pause/resume program for travel, illness, festival; illness days excluded from weight trend | P7 "life changes" is a top quit reason | Promote to MVP |
| A6 | **No-guilt copy rules**: no streaks (already), no red "failed" days, re-entry screen after 3+ silent days ("welcome back, here's what changed") instead of nagging | P7 "guilt" | MVP, copy + one screen state |
| A7 | **Paywall without pressure**: no countdowns or fake discounts; free assessment stays useful | P6 upsell complaints; blueprint trainer question 7 | MVP |
| A8 | **Protein target explained with both views**: food-first plan by default (matches ICMR), whey shown as optional if the gap stays > 20–30 g after food changes | ICMR stance vs Morton evidence; user trust | MVP |
| A9 | **Waist as the lead metric for fat loss** with Indian cut-offs as context | Indian cut-offs differ from Western | MVP, dashboard |
| A10 | **Step ramp ceiling**: ramp +1,000/week from baseline but stop at 8–10k (<60 y) / 6–8k (60+) | Paluch 2022 | MVP, F20 |
| A11 | **Fix CLAUDE.md protein anchor** (lean mass, not total weight) | Section 2 | Doc fix |

## 4. Round 2+3: Reddit scrape
- Round 2 (`zsxBhaUR24hkjCgOa`, 2026-10-05): 149 items from 8 of 12 queries. `docs/reddit_raw_round2.json`.
- Round 3 (`8duxhtIsAsTeBW8eN`, 2026-10-07): **674 items** (144 posts, 530 comments) from 10 queries targeting the Round-2 themes. `docs/reddit_raw_round3.json`. Cost combined ≈ $1.22.
Still a small corpus from last year; use for themes, not percentages. Posts tagged by keyword (one post can match several tags).

| Theme | Posts | Signal / verbatim example |
|---|---|---|
| **App complaints** | 67 | "Most fitness apps track everything. None tell you why you're stuck.", "Why is there no good free fitness app in India?" — this is literally the app's positioning |
| Plateau | 37 | "Progress stuck for months now", "Finally broke the plateau, turns out it was a me issue" |
| Whey too expensive | 26 | "Due to the recent price hike I cant afford quality whey", "Whey hustle- TWT too expensive" |
| Chest / lagging part | 25 | "Chest not growing", "chest still lags behind" |
| Skinny fat | 23 | "Skinny-fat to Lean muscular" (success story), "how to fix skinny fat (as a girl)" |
| PG / hostel / college | 22 | "Need a realistic diet plan for hostel life (no kitchen, only kettle)", "100g of protein as a college student living in a PG" |
| Tracking inaccurate for Indian food | 10 | "Every calorie app gets Indian food wrong. How do you actually track it?" — dal 90–400 kcal across entries, paneer 180–320 kcal |
| PCOD-friendly coach | 10 | "Looking for a fitness coach familiar with Indian diet (PCOD-friendly)" |
| Dietician search | 9 | explicit demand for the "coach" layer |
| GLP-1 / grey-market peptides / steroids | 6 | Mounjaro, Retatrutide, Ozempic — needs A17 guardrail |

Verbatim gold: a user wrote 65% off-ness in trackers (paneer 180–320, dal 90–400). This both validates the kcal-low/typ/high model and tells us users notice when a number is wrong — the app's confidence pill is a selling point, not just a safety feature.

| Theme | Posts (of 33) | Example (verbatim title) | What it confirms / adds |
|---|---|---|---|
| Fat loss stalled | ~10 | "Lost 10 kg in 3 months… now stuck. Need veg diet advice", "36m … stuck at 84kg" | P2. Replies are contradictory ("cut more", "more cardio", "refeed", "shock your body"); one reply: "Measure oil/ghee used". A1 + data-quality rung |
| Normal progress feels like failure | ~3 | "Have I actually plateaued, or am I being impatient?" (−4.2 kg in 6 weeks) | **A12** "Am I on track?" verdict |
| Skinny fat / no muscle after a year | ~4 | "NO PROGRESS SINCE LONG", "No progress at all" (skinny fat, PPL 6 days) | A3. Hinglish reply: "skinny fat hoke calorie deficit mat karne lagna… pehle muscle mass gain karlo" |
| Indian food data wrong in trackers | 2 | "I gave up on calorie tracker apps for Indian food. The macros are wrong everywhere" (paneer 180–320 kcal/100 g across MFP entries) | F7 ranges + source grades are the right call. **A15** packaged Indian protein products |
| Whey too expensive | 3 | "can't have more than 1 scoop per day (economic reasons)", "skip whey because of how expensive it has gotten" | **A16** budget-aware protein options |
| Following ChatGPT blindly | 2 | "blindly following Chatgpt", "ChatGPT somehow says I'm still in a deficit" | Positioning: numbers from your own logs, not a chatbot guess |
| Lose-regain cycles | 2 | "lose 5-6 kg … family functions, holidays, stress … gain it all back" | **A13** maintenance mode; Life happens (festival/travel) |
| Medical conditions | 4 | PCOD, high uric acid, low blood sugar, bad lipid panel | F21 confirmed. Uric acid needs a `high_purine` food tag later |
| Grey-market drugs | 1 | "Looking for a reliable source of Retatrutide in India" | **A17** guardrail |
| Overdoing cardio, little recovery | 1 | swimming 6 d/wk + MMA 6 d/wk, "what am I doing wrong?" | Recovery signal in diagnosis |
| PG / hostel food | 2 | "PG ka khana meri body pr lgta hi nhi", "hostel student" | **A14** who-controls-your-food at intake |
| Myths from family | 1 | "Doctor dad prevented me from lifting as I'll become 'bulky'" | Knowledge card topic (needs a source) |
| Program hopping, junk volume | 3 | "program hopping a lot", r/naturalbodybuilding: cut from 20+ sets/muscle, grew more | Individual volume (Scarpelli), upper bound matters |

Also seen: Hinglish posts and replies (confirms Hinglish-first); demand for live form correction (F11, still deferred).

## 5. Additions from round 2 + F21 (pre-approved)
| ID | Addition | Scope |
|---|---|---|
| A12 | **"Am I on track?"** verdict on Progress: actual rate vs expected band (0.5–1%/wk for fat loss), says "on pace" in plain words, explains day-to-day water swings | MVP |
| A13 | **Maintenance mode** after Goal reached: user-set weight band, nudge when the 7-day average leaves it | MVP-lite |
| A14 | **Intake: who controls your food** (`I cook / family cooks / PG-hostel-mess / mostly order`). Suggestions only use what that person can actually change | MVP |
| A15 | **Packaged Indian protein products** to Backlog (high-protein paneer, Amul protein drinks, soya chunks, sattu) from label values, grade B | Food DB |
| A16 | **Budget-aware protein options**: tag foods with a cost tier (low/med/high), not prices. Protein planner can rank by cost tier | MVP |
| A17 | **Drug/peptide/steroid guardrail**: classifier label `restricted_substance` in coach chat → no sourcing or dosing, "talk to a doctor", logged | MVP (safety) |
| A18 | **Whey rule (fits F21 "no supplement names")**: the app never suggests whey to someone who does not use it. If the user lists whey as their own protein source at intake, it can appear in their plan like any food they already eat | MVP. **Replaces A8** |
| A19 | Food tags `contains_fish`, `contains_soy`, `jain_ok`, `cost_tier`, later `high_purine`. Intake lists fish and soy, but the xlsx has no columns for them | Food DB |
| A5 (changed) | Life happens lite now covers travel / festival / busy only. Illness goes through the Not feeling well phase (screen 31, F21) | MVP |
| A20 | **"Hostel/PG mode"**: when `food_control = pg_hostel_mess`, the Eat-next planner stops suggesting from-scratch recipes and only picks items the user can realistically control (whey/sattu, boiled eggs if non-veg, curd pouch, bananas, dry oats + water, roasted chana). Mess thali itself goes in as a user "estimate" with wide ranges | MVP |
| A21 | **PCOD at intake** as a `conditions text[]` field (not a diagnosis-based rule). Flags only unlock: slower fat-loss target (0.5%/wk floor), waist-centric dashboard, mention of resistance training's role; the app never prescribes medical advice. Dietician discovery stays out of MVP | MVP |
| A22 | **"Confidence pill" on every number** (Progress screen already shows status; extend to Today's kcal/protein, Food log result, Diagnosis). Each number carries `confidence_tag` so the user sees why a value is a range | MVP |
| A23 | **Cost-tier aware search sort**: foods ranked by `protein_per_rupee` fallback when the user hits "cheaper options" on Eat-next (A16-adjacent) | MVP |
