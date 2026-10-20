"""Regression tests for harvest_local.harvest:
- headless (SDK / `claude -p`) runs carry entrypoint sdk-*; they must be flagged so the
  report can score rates on interactive sessions only (headless batch runs were 40% of all
  sessions and dragged every rate).
- lines_added / lines_removed were never computed, so the KPI read 0.
"""
import importlib.util, json, os, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SKILL = os.path.dirname(HERE)
spec = importlib.util.spec_from_file_location("harvest_local", os.path.join(SKILL, "harvest_local.py"))
hl = importlib.util.module_from_spec(spec); spec.loader.exec_module(hl)


def _transcript(entrypoint, tool_inputs):
    recs = [{"type": "user", "timestamp": "2026-09-01T10:00:00.000Z", "cwd": "/home/x/Repos/p",
             "entrypoint": entrypoint, "message": {"content": "do the thing"}}]
    for i, (name, inp) in enumerate(tool_inputs):
        recs.append({"type": "assistant", "timestamp": "2026-09-01T10:0%d:00.000Z" % (i + 1),
                     "entrypoint": entrypoint,
                     "message": {"content": [{"type": "tool_use", "id": "t%d" % i, "name": name, "input": inp}]}})
    f = tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False)
    f.write("\n".join(json.dumps(r) for r in recs)); f.close()
    return f.name


def _harvest(path):
    hl.START, hl.END = "2026-01-01", "2026-12-31"
    return hl.harvest(path)


def test_sdk_entrypoint_is_headless():
    m = _harvest(_transcript("sdk-cli", []))
    assert m["entrypoint"] == "sdk-cli"
    assert m["headless"] is True


def test_cli_entrypoint_is_not_headless():
    m = _harvest(_transcript("cli", []))
    assert m["headless"] is False


def test_lines_added_and_removed_counted():
    m = _harvest(_transcript("cli", [
        ("Edit", {"file_path": "/a.py", "old_string": "x = 1\ny = 2", "new_string": "x = 1\ny = 3\nz = 4"}),
        ("Write", {"file_path": "/b.py", "content": "a\nb\nc\nd\n"}),
        ("MultiEdit", {"file_path": "/c.py", "edits": [{"old_string": "q", "new_string": "r\ns"}]}),
    ]))
    # Edit: +3 -2, Write: +4, MultiEdit: +2 -1
    assert m["lines_added"] == 9
    assert m["lines_removed"] == 3


def test_every_cwd_is_recorded_for_mid_session_worktrees():
    # EnterWorktree moves a session from <repo> into <repo>/.claude/worktrees/x after it
    # starts, so the first cwd alone hid most worktree sessions from Isolation discipline.
    path = _transcript("cli", [])
    with open(path, "a") as fh:
        fh.write("\n" + json.dumps({"type": "user", "timestamp": "2026-09-01T10:05:00.000Z",
                                    "cwd": "/home/x/Repos/p/.claude/worktrees/feat", "message": {"content": "next"}}))
    m = _harvest(path)
    assert m["project_path"] == "/home/x/Repos/p"
    assert "/home/x/Repos/p/.claude/worktrees/feat" in m["cwds"]


if __name__ == "__main__":
    mod = sys.modules[__name__]; failed = 0
    for name in [n for n in dir(mod) if n.startswith("test_")]:
        try: getattr(mod, name)(); print("PASS", name)
        except Exception as exc: failed += 1; print("FAIL", name, repr(exc))
    raise SystemExit(1 if failed else 0)
