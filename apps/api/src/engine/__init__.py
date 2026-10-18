"""Tier-1 rule engine: deterministic functions that compute every number the app shows.

No I/O, no model calls. Callers pass plain values in and get plain values out, so each
rule can be unit-tested and a wrong number shows up as a failing test.
"""

ENGINE_VERSION = "0.1.0"
