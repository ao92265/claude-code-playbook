"""Payload allowlist, clamping, and no-network regression tests for the export path.

Privacy contract: scores.json is the ONLY artifact allowed to leave the machine, and it
may contain nothing beyond the allowlisted keys. NOTE — the PRD's literal validation
grep ('ev|lever|...') would false-positive on substrings inside legitimate values
("Delegation leverage", "formula_version"), so these tests check JSON KEY NAMES and
forbidden top-level fields precisely instead.
"""
import json, os, re, sys, glob

HERE = os.path.dirname(os.path.abspath(__file__))
SKILL = os.path.dirname(HERE)
sys.path.insert(0, SKILL)
from export_scores import build_payload  # noqa: E402
from scorecard import compute_scores  # noqa: E402

FIXTURE = os.path.join(HERE, "fixtures", "quant_fixture.json")


def _all_keys(obj, acc):
    if isinstance(obj, dict):
        for k, v in obj.items():
            acc.add(k); _all_keys(v, acc)
    elif isinstance(obj, list):
        for v in obj:
            _all_keys(v, acc)
    return acc


def test_payload_allowlist_shape():
    q = json.load(open(FIXTURE))
    d = build_payload(q)
    assert set(d) == {"schema_version", "formula_version", "corpus", "factors",
                      "composite", "grade", "skill_version"}
    assert set(d["corpus"]) == {"n_sessions", "n_facets", "active_days", "as_of"}
    assert all(set(f) == {"name", "score", "kind", "w"} for f in d["factors"])
    assert all(0 <= f["score"] <= 100 for f in d["factors"])
    assert 0 <= d["composite"] <= 100


def test_payload_contains_no_forbidden_keys():
    q = json.load(open(FIXTURE))
    keys = _all_keys(build_payload(q), set())
    forbidden = {"ev", "lever", "top_project_areas", "by_hour", "busiest_days",
                 "input_tokens", "output_tokens", "top_tools", "top_languages",
                 "error_categories", "facet_outcomes", "facet_frictions"}
    assert not (keys & forbidden), keys & forbidden


def test_export_clamps_push_through_over_100():
    q = json.load(open(FIXTURE))
    q["pushes"] = 150  # > commits (100): report variant may exceed 100
    rep, _ = compute_scores(q, variant="report")
    exp, _ = compute_scores(q, variant="export")
    rep_pt = next(f["score"] for f in rep if f["name"] == "Push-through")
    exp_pt = next(f["score"] for f in exp if f["name"] == "Push-through")
    assert rep_pt == 150.0, "report variant must stay unclamped (formula freeze)"
    assert exp_pt == 100.0, "export variant must clamp to 100"


def test_export_clamps_negative_reliability():
    q = json.load(open(FIXTURE))
    q["tool_errors"] = 2000  # > counted calls (1000): reliability goes negative
    rep, _ = compute_scores(q, variant="report")
    exp, _ = compute_scores(q, variant="export")
    rep_tr = next(f["score"] for f in rep if f["name"] == "Tool reliability")
    exp_tr = next(f["score"] for f in exp if f["name"] == "Tool reliability")
    assert rep_tr == -100.0
    assert exp_tr == 0.0


def test_no_network_code_paths():
    """No-config-no-network regression: no skill module may import a network-capable
    library. The skill has no submission endpoint yet; nothing may phone home."""
    banned = re.compile(
        r"^\s*(import|from)\s+(urllib|requests|http\.client|httpx|socket|aiohttp)\b",
        re.M)
    for path in glob.glob(os.path.join(SKILL, "*.py")):
        src = open(path).read()
        assert not banned.search(src), f"network import found in {os.path.basename(path)}"
