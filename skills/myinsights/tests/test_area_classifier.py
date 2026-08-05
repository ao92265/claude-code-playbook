"""Regression test: gather_all.area_of must bucket worktrees as scratch/worktree.

The original ordering tested "/repos/" before the scratch/worktree test. Git worktrees
commonly live under a repo root (~/Repos/.agent-worktrees/<id>), so every worktree session
was bucketed as a repo literally named ".agent-worktrees". scratch/worktree then never
appeared in top_project_areas, and the Isolation discipline factor — which looks that name
up by exact string — scored 0 for someone using worktrees correctly.

Ordering is the contract here, not the individual branches. Keep the scratch test first.
"""
import importlib.util, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SKILL = os.path.dirname(HERE)


def _area_of():
    """Load area_of without executing gather_all's module-level scan of ~/.claude."""
    src = open(os.path.join(SKILL, "gather_all.py"), encoding="utf-8").read()
    start = src.index("def area_of(")
    end = src.index("\nfor ", start)
    ns = {}
    exec("import os, re\n" + src[start:end], ns)
    return ns["area_of"]


def test_worktree_under_repos_is_scratch_not_a_repo():
    area_of = _area_of()
    assert area_of("/Users/x/Repos/.agent-worktrees/abc-TASK-1") == "scratch/worktree"
    assert area_of("/Users/x/repos/.agent-worktrees/abc") == "scratch/worktree"


def test_scratchpad_and_tmp_still_scratch():
    area_of = _area_of()
    assert area_of("/tmp/claude-502/whatever") == "scratch/worktree"
    assert area_of("/Users/x/Repos/proj/scratchpad/run") == "scratch/worktree"


def test_ordinary_repo_still_resolves_to_its_name():
    area_of = _area_of()
    assert area_of("/Users/x/Repos/vanguardplanner") == "vanguardplanner"
    assert area_of("/Users/x/Repos/vanguardplanner/src/app") == "vanguardplanner"


def test_empty_and_unknown_paths():
    area_of = _area_of()
    assert area_of("") == "other"
    assert area_of("/opt/somewhere/else") == "else"


if __name__ == "__main__":
    mod = sys.modules[__name__]
    failed = 0
    for name in [n for n in dir(mod) if n.startswith("test_")]:
        try:
            getattr(mod, name)()
            print("PASS", name)
        except Exception as exc:  # noqa: BLE001
            failed += 1
            print("FAIL", name, repr(exc))
    raise SystemExit(1 if failed else 0)
