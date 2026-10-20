"""Shared parser for real git commit / git push runs (hooks/lib/git_commands.py)."""
import os, sys
sys.path.insert(0, os.path.expanduser("~/.claude/hooks/lib"))
from git_commands import git_actions

def acts(cmd): return [a for a, _ in git_actions(cmd) if a != "cd"]

CASES = [
    ("git commit -m a && git push", ["commit", "push"]),
    ('git commit -m "fix push gate"', ["commit"]),
    ("git stash push", []),
    ("git push --dry-run", []),
    ('echo "git commit later"', []),
    ("git -c x=y commit -m a", ["commit"]),
    ("/usr/bin/git push", ["push"]),
    ("if true; then git push; fi", ["push"]),
    ("! git push", ["push"]),
    ("exec git push", ["push"]),
    ("timeout 60 git push", ["push"]),
    ("env -u X git commit -m a", ["commit"]),
    ("git \\\npush origin main", ["push"]),
    ("git commit -m wip#2 && git push", ["commit", "push"]),
    ("git commit -m a # then git push", ["commit"]),
    ("git commit -F - <<'EOF'\nNow detects (git push) runs\nit's fine\nEOF\nls", ["commit"]),
    ("cat <<-EOF\n\tgit push\n\tEOF\ngit push", ["push"]),
]

def test_cases():
    bad = [(c, acts(c), w) for c, w in CASES if acts(c) != w]
    assert not bad, bad

def test_variable_folder_is_dropped():
    assert list(git_actions('git -C "$X" commit -m a')) == [("commit", None)]
    assert list(git_actions('cd "$REPO" && git commit -m a')) == [("commit", None)]

if __name__ == "__main__":
    failed = 0
    for n, f in sorted(globals().items()):
        if n.startswith("test_"):
            try: f(); print("PASS", n)
            except Exception as e: failed += 1; print("FAIL", n, e)
    raise SystemExit(1 if failed else 0)
