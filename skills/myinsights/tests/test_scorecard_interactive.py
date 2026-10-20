"""Isolation discipline and Delegation leverage are per-session rates; headless runs
(scripted SDK batches) dilute them. When quant.json carries an `interactive` block,
those two rates must use it instead of the all-session totals."""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
from scorecard import compute_scores  # noqa: E402

FIXTURE = os.path.join(HERE, "fixtures", "quant_fixture.json")


def _scores(q):
    F, _ = compute_scores(q)
    return {f["name"]: f["score"] for f in F}


def test_interactive_block_drives_isolation_and_delegation():
    q = json.load(open(FIXTURE))
    q["interactive"] = {"sessions": 100, "worktree_sessions": 30, "task_agent_sessions": 15}
    s = _scores(q)
    assert abs(s["Isolation discipline"] - 30.0) < 1e-9   # 30/100, not 120/200
    assert abs(s["Delegation leverage"] - 75.0) < 1e-9    # (15/100)/0.2


def test_no_interactive_block_keeps_old_numbers():
    s = _scores(json.load(open(FIXTURE)))
    assert abs(s["Isolation discipline"] - 60.0) < 1e-9
    assert abs(s["Delegation leverage"] - 50.0) < 1e-9


if __name__ == "__main__":
    mod = sys.modules[__name__]; failed = 0
    for name in [n for n in dir(mod) if n.startswith("test_")]:
        try: getattr(mod, name)(); print("PASS", name)
        except Exception as exc: failed += 1; print("FAIL", name, repr(exc))
    raise SystemExit(1 if failed else 0)
