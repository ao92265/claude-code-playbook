"""Spread tests for the calibrated (v2) scorecard variant.

The v1 'report' variant compresses every realistic profile into the B/B+ band: its
four rare-event factors sit at 91-97 for anyone (a pedestal) while ship cadence and
isolation sit near 0 for anyone (a drag). Perfect work scored 80.1 and mediocre work
scored 65.3, a 15-point spread across the entire human range.

v2 maps each factor's realistic operating band onto the full 0-100 scale, so the
grade moves when the work moves. These tests pin that property, not exact numbers.
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
from scorecard import (  # noqa: E402
    compute_scores, grade_of, CALIBRATION, FORMULA_VERSION_CALIBRATED,
)

FIXTURE = os.path.join(HERE, "fixtures", "quant_fixture.json")


def _profile(landing, buggy, wrong, unclear, n=100, **infra):
    """Synthetic quant.json. landing/buggy/wrong/unclear are fractions of n facets."""
    q = dict(
        sessions=200, commits=115, pushes=95, active_days=17, tool_errors=368,
        task_agent_sessions=21, facet_n=n,
        top_tools=[["Bash", 7373]],
        top_project_areas=[["scratch/worktree", 35]],
        facet_outcomes=[["fully_achieved", int(landing * n)],
                        ["unclear_from_transcript", int(unclear * n)]],
        facet_frictions=[["buggy_code", int(buggy * n)],
                         ["wrong_approach", int(wrong * n)]],
    )
    q.update(infra)
    return q


PERFECT = _profile(1.0, 0.0, 0.0, 0.0, commits=136, pushes=136,
                   tool_errors=0, task_agent_sessions=80,
                   top_project_areas=[["scratch/worktree", 100]])
GOOD = _profile(0.86, 0.09, 0.06, 0.03)
MEDIOCRE = _profile(0.60, 0.20, 0.20, 0.08)
BAD = _profile(0.30, 0.40, 0.40, 0.15, commits=5, pushes=0,
               tool_errors=2000, task_agent_sessions=0, top_project_areas=[])


def _comp(q):
    return compute_scores(q, variant="calibrated")[1]


def test_realistic_range_spans_most_of_the_scale():
    """The defect: v1 put PERFECT at 80.1 and MEDIOCRE at 65.3. v2 must do better."""
    assert _comp(PERFECT) - _comp(MEDIOCRE) > 40


def test_grades_are_distinguishable():
    grades = [grade_of(_comp(p)) for p in (PERFECT, GOOD, MEDIOCRE, BAD)]
    assert len(set(grades)) == 4, f"profiles must not share a grade: {grades}"
    assert grades[0] in ("A+", "A")
    assert grades[-1] in ("C", "D")


def test_monotonic_in_landing_rate():
    """Strictly rising inside the band, never falling above it (saturation is intended)."""
    prev = -1
    for landing in (0.55, 0.65, 0.75, 0.85, 0.95):  # 0.50 is the floor, 0.95 the ceiling
        c = _comp(_profile(landing, 0.1, 0.1, 0.05))
        assert c > prev, "composite must rise with landing rate inside the band"
        prev = c
    assert _comp(_profile(1.0, 0.1, 0.1, 0.05)) >= prev, "must not fall above the ceiling"
    assert _comp(_profile(0.2, 0.1, 0.1, 0.05)) == _comp(_profile(0.4, 0.1, 0.1, 0.05)), \
        "below the floor the factor is saturated at 0 by design"


def test_all_factors_clamped():
    for p in (PERFECT, GOOD, MEDIOCRE, BAD):
        for f in compute_scores(p, variant="calibrated")[0]:
            assert 0.0 <= f["score"] <= 100.0, f"{f['name']} out of range: {f['score']}"


def test_bands_are_disclosed_in_evidence():
    """Every calibrated factor must state its own band, or the score is unexplainable."""
    factors, _ = compute_scores(GOOD, variant="calibrated")
    assert len(factors) == 9
    assert sum(f["w"] for f in factors) == 100
    for f in factors:
        assert f["name"] in CALIBRATION
        assert "scale" in f["ev"], f"{f['name']} does not disclose its band"


def test_v1_report_variant_untouched():
    """Old submissions and the export wire format must keep their meaning."""
    q = json.load(open(FIXTURE))
    _, comp = compute_scores(q, variant="report")
    assert abs(comp - 70.9) < 1e-9
    assert FORMULA_VERSION_CALIBRATED != "1.0"
