#!/usr/bin/env python3
"""push-gate.py: Stop hook. A session that committed and then did not push gets
ONE nudge before it ends: push, or say in one line why not.

Why: Push-through is a weak myinsights factor. On 6 Oct 2026, 113 of 328
interactive sessions that committed ended with commits that had not been pushed.
Unpushed work is invisible to teammates and lives on one machine.

Never nudged: headless runs (pipelines commit locally on purpose), repos with no
remote, repos named in the allow list (one repo folder name per line, default
~/.claude/state/push-gate-allow), and the second stop in a row (stop_hook_active),
so a stated reason always lets the session end. Fails open on any error.

Disable: CLAUDE_SKIP_HOOKS=push-gate, set when launching claude.
"""
import json, os, subprocess, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
from git_commands import git_actions  # noqa: E402

GATED = ("cli", "claude-vscode", "claude-desktop", "claude-desktop-3p")


def git(d, *args):
    r = subprocess.run(["git", "-C", d, *args], capture_output=True, text=True, timeout=10)
    return r.stdout.strip() if r.returncode == 0 else None


def check(top, since):
    """None when nothing to say, else a short description of what is unpushed."""
    if not git(top, "remote"):
        return None                                   # nowhere to push to
    has_up = git(top, "config", "--get", "branch.%s.merge" % (git(top, "branch", "--show-current") or "-"))
    up = git(top, "rev-parse", "--verify", "-q", "@{u}")
    if has_up and not up:
        return None                                   # upstream gone: merged and pruned
    rng = ["@{u}..HEAD"] if up else ["HEAD", "--not", "--remotes"]
    n = int(git(top, "rev-list", "--count", "--since=" + since, *rng) or 0) if since else 0
    if not n:
        return None
    behind = int(git(top, "rev-list", "--count", "HEAD..@{u}") or 0) if up else 0
    if behind:
        return f"{top} ({n} new commits, diverged from upstream by {behind}: say how it lands)"
    return f"{top} ({n} new commits not pushed)"


def main():
    skip = os.environ.get("CLAUDE_SKIP_HOOKS", "") + "," + os.environ.get("OMC_SKIP_HOOKS", "")
    if "push-gate" in skip.split(","):
        return 0
    inp = json.load(sys.stdin)
    if inp.get("stop_hook_active"):
        return 0
    cwd = inp.get("cwd") or os.getcwd()
    entry = os.environ.get("CLAUDE_CODE_ENTRYPOINT", "cli")
    since, pending = None, []  # folders where a commit ran
    with open(inp["transcript_path"], errors="replace") as f:
        for line in f:
            if since is None or '"entrypoint"' in line or '"Bash"' in line:
                try:
                    rec = json.loads(line)
                except ValueError:
                    continue
                since = since or rec.get("timestamp")
                entry = rec.get("entrypoint") or entry
                if '"Bash"' not in line:
                    continue
                content = (rec.get("message") or {}).get("content")
                for b in content if isinstance(content, list) else []:
                    if not (isinstance(b, dict) and b.get("type") == "tool_use" and b.get("name") == "Bash"):
                        continue
                    here = rec.get("cwd") or cwd       # the folder this call ran in
                    for act, folder in git_actions((b.get("input") or {}).get("command") or ""):
                        if act == "cd":
                            here = os.path.join(here, os.path.expanduser(folder))
                        elif act == "commit":
                            pending.append(os.path.join(here, os.path.expanduser(folder)) if folder else here)
                    # A push is not trusted to clear anything: it may be another repo, or
                    # rejected. check() asks git whether each commit folder is pushed.
    if entry not in GATED or not pending:
        return 0
    allow_file = os.environ.get("PUSH_GATE_ALLOW", os.path.expanduser("~/.claude/state/push-gate-allow"))
    try:
        allow = {l.strip() for l in open(allow_file) if l.strip()}
    except OSError:
        allow = set()
    found, seen, sig = [], set(), []
    for d in pending:
        top = git(d, "rev-parse", "--show-toplevel") if os.path.isdir(d) else None
        if not top or top in seen or os.path.basename(top) in allow:
            continue
        seen.add(top)
        msg = check(top, since)
        if msg:
            found.append(msg)
            sig.append(top + "@" + (git(top, "rev-parse", "HEAD") or ""))
    if not found:
        return 0
    # Once per state: a reason given on one turn is not asked for again until HEAD moves.
    state = os.environ.get("PUSH_GATE_STATE", os.path.expanduser("~/.claude/state"))
    mark = os.path.join(state, "pushgate-" + str(inp.get("session_id") or "nosession"))
    sig = "\n".join(sorted(sig))
    try:
        if open(mark).read() == sig:
            return 0
    except OSError:
        pass
    try:
        os.makedirs(state, exist_ok=True)
        open(mark, "w").write(sig)
    except OSError:
        pass
    print("push-gate: this session committed but did not push: " + "; ".join(found)
          + ". Push now on a feature branch, or reply with one line saying why it stays"
          " local. If a repo should always stay local, add its folder name to"
          " ~/.claude/state/push-gate-allow. You will not be asked again for these commits.",
          file=sys.stderr)
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:  # a nudge must never wedge a session
        sys.exit(0)
