"""graveyard-sweep must list branches that track an upstream but hold commits never
pushed for over a day. orphaned_branches only catches branches with NO upstream, so
committed-but-unpushed work on a tracked branch went unreported (push-through 63%)."""
import importlib.util, os, subprocess, sys, tempfile, time

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("gs", os.path.join(os.path.dirname(HERE), "graveyard-sweep.py"))
gs = importlib.util.module_from_spec(spec); spec.loader.exec_module(gs)


def git(cwd, *a, env=None):
    subprocess.run(["git", *a], cwd=cwd, check=True, capture_output=True, env=env)


def _repo(unpushed_age_hours):
    root = tempfile.mkdtemp()
    remote, work = os.path.join(root, "remote.git"), os.path.join(root, "work")
    git(root, "init", "--bare", "-q", remote)
    git(root, "clone", "-q", remote, work)
    for k, v in (("user.email", "t@t"), ("user.name", "t"), ("commit.gpgsign", "false")):
        git(work, "config", k, v)
    git(work, "commit", "-q", "--allow-empty", "-m", "base")
    git(work, "push", "-q", "-u", "origin", "HEAD")
    if unpushed_age_hours is not None:
        when = "@%d +0000" % int(time.time() - unpushed_age_hours * 3600)
        env = dict(os.environ, GIT_COMMITTER_DATE=when, GIT_AUTHOR_DATE=when)
        git(work, "commit", "-q", "--allow-empty", "-m", "local only", env=env)
    return work


def test_old_unpushed_commit_is_reported():
    f = gs.unpushed_commits([_repo(48)])
    assert len(f) == 1 and "1 unpushed" in f[0], f


def test_fresh_unpushed_commit_is_quiet():
    assert gs.unpushed_commits([_repo(2)]) == []


def test_clean_repo_is_quiet():
    assert gs.unpushed_commits([_repo(None)]) == []


def test_clones_of_one_remote_collapse_to_one_line():
    a = _repo(48)
    remote = git_url(a)
    b = os.path.join(os.path.dirname(a), "copy")
    git(os.path.dirname(a), "clone", "-q", remote, b)
    for k, v in (("user.email", "t@t"), ("user.name", "t"), ("commit.gpgsign", "false")):
        git(b, "config", k, v)
    when = "@%d +0000" % int(time.time() - 72 * 3600)
    git(b, "commit", "-q", "--allow-empty", "-m", "other local", env=dict(os.environ, GIT_COMMITTER_DATE=when))
    assert len(gs.unpushed_commits([a, b])) == 2  # both copies really are ahead
    lines = gs.unpushed_by_repo([a, b])
    assert len(lines) == 1 and "1 branch" in lines[0], lines


def git_url(repo):
    return subprocess.run(["git", "remote", "get-url", "origin"], cwd=repo, capture_output=True, text=True).stdout.strip()


if __name__ == "__main__":
    failed = 0
    for n in [n for n in dir(sys.modules[__name__]) if n.startswith("test_")]:
        try: globals()[n](); print("PASS", n)
        except Exception as e: failed += 1; print("FAIL", n, repr(e))
    raise SystemExit(1 if failed else 0)
