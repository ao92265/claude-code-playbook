"""Push-through must score sessions that left commits unpushed, not the ratio of
push commands to commit commands. One push sends many commits, so the old ratio
could only reach 100 by pushing after every single commit (found 6 Oct 2026)."""
import importlib.util, json, os, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SKILL = os.path.dirname(HERE)
sys.path.insert(0, SKILL)
spec = importlib.util.spec_from_file_location("harvest_local", os.path.join(SKILL, "harvest_local.py"))
hl = importlib.util.module_from_spec(spec); spec.loader.exec_module(hl)
from scorecard import compute_scores  # noqa: E402


def _session(cmds):
    recs = [{"type": "user", "timestamp": "2026-09-01T10:00:00.000Z", "cwd": "/home/x/Repos/p",
             "entrypoint": "cli", "message": {"content": "go"}}]
    for i, c in enumerate(cmds):
        recs.append({"type": "assistant", "timestamp": "2026-09-01T10:01:00.000Z", "entrypoint": "cli",
                     "message": {"content": [{"type": "tool_use", "id": "t%d" % i, "name": "Bash",
                                              "input": {"command": c}}]}})
    f = tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False)
    f.write("\n".join(json.dumps(r) for r in recs)); f.close()
    hl.START, hl.END = "2026-01-01", "2026-12-31"
    return hl.harvest(f.name)


def test_three_commits_one_push_is_fully_pushed():
    m = _session(["git commit -m a", "git commit -m b", "git commit -m c", "git push"])
    assert m["ended_unpushed"] is False


def test_commit_after_last_push_is_unpushed():
    m = _session(["git commit -m a", "git push", "git commit -m b"])
    assert m["ended_unpushed"] is True


def test_commit_and_push_in_one_command():
    m = _session(["git commit -m a && git push"])
    assert m["ended_unpushed"] is False


def test_word_push_in_a_commit_message_is_not_a_push():
    m = _session(['git commit -m "fix push gate"', "git stash push"])
    assert m["ended_unpushed"] is True


def test_no_commits_is_not_a_committing_session():
    m = _session(["ls"])
    assert m["ended_unpushed"] is None


def test_scorecard_scores_committing_sessions_that_pushed():
    q = json.load(open(os.path.join(HERE, "fixtures", "quant_fixture.json")))
    q["commits"], q["pushes"] = 100, 10          # old ratio would say 10%
    q["commit_sessions"], q["commit_sessions_unpushed"] = 10, 1
    F, _ = compute_scores(q)
    pt = [f for f in F if f["name"] == "Push-through"][0]
    assert abs(pt["raw"] - 0.9) < 1e-9, pt["raw"]
    assert "9 of 10" in pt["ev"] and "not confirmed" in pt["ev"], pt["ev"]


def test_scorecard_falls_back_without_session_counts():
    q = json.load(open(os.path.join(HERE, "fixtures", "quant_fixture.json")))
    q.pop("commit_sessions", None); q.pop("commit_sessions_unpushed", None)
    q["commits"], q["pushes"] = 100, 50
    F, _ = compute_scores(q)
    pt = [f for f in F if f["name"] == "Push-through"][0]
    assert abs(pt["raw"] - 0.5) < 1e-9


if __name__ == "__main__":
    import inspect
    failed = 0
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and inspect.isfunction(fn):
            try:
                fn(); print("PASS", name)
            except Exception as exc:  # noqa: BLE001
                failed += 1; print("FAIL", name, repr(exc))
    raise SystemExit(1 if failed else 0)
