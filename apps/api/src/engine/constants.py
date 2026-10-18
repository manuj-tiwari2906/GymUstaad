"""Every number the engine relies on, with its source and check status.

Status values:
- "checked": matched against the paper abstract / publisher page (docs/research.md).
- "verify": standard textbook value used from memory. Must be checked against the primary
  source before launch. Tests pin the current value so a change is deliberate.
"""

# Energy ---------------------------------------------------------------------

# Mifflin-St Jeor 1990 (AJCN). status: verify
MSJ_WEIGHT = 10.0
MSJ_HEIGHT = 6.25
MSJ_AGE = 5.0
MSJ_MALE = 5.0
MSJ_FEMALE = -161.0

# Starting multipliers on BMR before the adaptive estimate (A1) has data. status: verify
# Only a first guess; maintenance.py replaces it once logs + weight trend exist.
ACTIVITY_FACTOR = {"desk": 1.4, "mixed": 1.55, "on_feet": 1.7}

# Energy in 1 kg of body-mass change, used for rate <-> kcal conversion. status: verify
KCAL_PER_KG = 7700.0

# Fat loss rate band, % bodyweight per week. Helms 2014; Garthe 2011 (0.7). status: checked
FAT_LOSS_RATE_MIN = 0.5
FAT_LOSS_RATE_DEFAULT = 0.7
FAT_LOSS_RATE_MAX = 1.0
# Blueprint guardrail: flag loss faster than ~1%/wk.
FAST_LOSS_FLAG = 1.0

# Calorie floor: never set a target below max(floor, BMR). Floor value status: verify.
KCAL_FLOOR = {"male": 1500.0, "female": 1200.0}

# Lean gain surplus as % of maintenance. status: verify
MUSCLE_GAIN_SURPLUS_PCT = 0.10

# Protein ----------------------------------------------------------------------

# Morton 2018 breakpoint 1.62 g/kg/day, 95% CI 1.03-2.20. status: checked
PROTEIN_GAIN_G_PER_KG = 1.6
PROTEIN_GAIN_UPPER_G_PER_KG = 2.2
# Helms 2014: 2.3-3.1 g/kg LEAN body mass for lean lifters in a cut. status: checked
PROTEIN_CUT_G_PER_KG_LBM = (2.3, 3.1)

# Trend ------------------------------------------------------------------------

# CLAUDE.md F19: "not enough data" under 10 days.
MIN_TREND_DAYS = 10
# Exponential smoothing for daily weight. status: verify (design choice, not a paper value)
WEIGHT_EMA_ALPHA = 0.1

# Training volume ---------------------------------------------------------------

# Baz-Valle 2022: 12-20 hard sets per muscle per week. status: checked (abstract via research)
WEEKLY_SETS_LOW = 12
WEEKLY_SETS_HIGH = 20
# A set counts as "hard" when RIR <= this. DB stores 3 as "3+", so 3 is excluded. status: verify
HARD_SET_MAX_RIR = 2

# Walking: ACSM metabolic equation ---------------------------------------------

# VO2 (ml/kg/min) = 3.5 + 0.1*S + 1.8*S*G, S in m/min, G as a fraction. status: verify
ACSM_REST = 3.5
ACSM_HORIZONTAL = 0.1
ACSM_VERTICAL = 1.8
# Valid speed range for the walking equation, m/min (about 3-6 km/h). status: verify
ACSM_WALK_SPEED_MIN = 50.0
ACSM_WALK_SPEED_MAX = 100.0
# kcal per litre of O2. status: verify
KCAL_PER_L_O2 = 5.0

# Steps (F20) -------------------------------------------------------------------

STEP_RAMP_PER_WEEK = 1000
# Paluch 2022: benefit plateaus 8-10k (<60 y) and 6-8k (60+). Ceiling = top of band. status: checked
STEP_CEILING_UNDER_60 = 10000
STEP_CEILING_60_PLUS = 8000

# Oil rule C --------------------------------------------------------------------

# 1 tbsp oil ~13.5 g x 9 kcal/g. status: verify
KCAL_PER_TBSP_OIL = 120.0
OIL_TBSP = {"less": -0.5, "normal": 0.0, "extra": 1.0}

# Body composition flags -------------------------------------------------------

# WHO 2004 Asian BMI action point (overweight). status: checked
ASIAN_BMI_OVERWEIGHT = 23.0
# IDF South Asian waist cut-offs, cm. status: checked
WAIST_CUTOFF_CM = {"male": 90.0, "female": 80.0}
