"""Golden-file test: scorecard.py (variant='report') must reproduce the pre-refactor
inline renderer's scores exactly, for a synthetic checked-in fixture.

Expected values are hand-derived from the disclosed formulas — if a formula changes,
this test MUST fail until FORMULA_VERSION_* is bumped and the goldens are re-derived.
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
from scorecard import compute_scores, grade_of, SCHEMA_VERSION  # noqa: E402

FIXTURE = os.path.join(HERE, "fixtures", "quant_fixture.json")

# Hand-derived from the formulas (see scorecard.py):
#   Ship cadence      100*(100/10)/25          = 40.0
#   Tool reliability  100*(1-20/1000)          = 98.0
#   Survival rate     100*(1-5/50)             = 90.0
#   Landing rate      100*35/50                = 70.0
#   Approach accuracy 100*(1-5/50)             = 90.0
#   Isolation         100*120/200              = 60.0
#   Clean first pass  100*(1-10/50)            = 80.0
#   Push-through      100*50/100               = 50.0
#   Delegation        min(100,100*(20/200)/.2) = 50.0
GOLDEN = {
    "Ship cadence": 40.0,
    "Tool reliability": 98.0,
    "Survival rate": 90.0,
    "Landing rate": 70.0,
    "Approach accuracy": 90.0,
    "Isolation discipline": 60.0,
    "Clean first pass": 80.0,
    "Push-through": 50.0,
    "Delegation leverage": 50.0,
}
GOLDEN_COMPOSITE = 70.9  # (40*10+98*5+90*10+70*20+90*15+60*10+80*15+50*10+50*5)/100
GOLDEN_GRADE = "B+"


def test_factor_scores_bit_identical():
    q = json.load(open(FIXTURE))
    factors, composite = compute_scores(q, variant="report")
    got = {f["name"]: f["score"] for f in factors}
    assert got == GOLDEN, f"scorecard drifted from golden: {got}"
    assert abs(composite - GOLDEN_COMPOSITE) < 1e-9
    assert grade_of(composite) == GOLDEN_GRADE


def test_factors_sorted_and_weighted():
    q = json.load(open(FIXTURE))
    factors, _ = compute_scores(q, variant="report")
    scores = [f["score"] for f in factors]
    assert scores == sorted(scores, reverse=True), "factors must be ranked best-first"
    assert sum(f["w"] for f in factors) == 100, "weights must total 100"
    assert len(factors) == 9
    assert SCHEMA_VERSION == 1


def test_report_variant_matches_export_when_in_range():
    """For a fixture where nothing exceeds [0,100], variants must agree exactly."""
    q = json.load(open(FIXTURE))
    rep, comp_r = compute_scores(q, variant="report")
    exp, comp_e = compute_scores(q, variant="export")
    assert [(f["name"], f["score"]) for f in rep] == [(f["name"], f["score"]) for f in exp]
    assert comp_r == comp_e
