#!/usr/bin/env python3
"""test-gate.py - Stop hook. A session that changed source code cannot stop until
something has run that code after the last change. Blocks once per session.

Why: buggy first passes are the second-biggest friction in the insights report
(8 sessions). The cheapest catch is running the thing before saying it is done.

What counts as running it, after the last source edit:
  - a test runner, a build or a typecheck (same list as evidence-recorder.sh)
  - a test script (anything named test_*, *_test.*, *.test.*, or under tests/)
  - a command that names a changed file without only reading it (python3 x.py)
  - a request to the app running on this machine, or a deploy (helm, kubectl)
  - the /done skill, or the run, demo-qa or verification skills
Reading a changed file (cat, git diff, grep) is not running it.

Edits come from the main transcript and from subagent transcripts, using the
same rules as the review gate in verify-gate.sh (shared through lib/edit_scan.py).

Exit codes: 0 allow, 2 block. Fails open on anything unexpected.
Disable: CLAUDE_SKIP_HOOKS=test-gate
"""
import json
import os
import re
import shlex
import sys
import time
from collections import deque
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
try:
    import edit_scan as es
except Exception:  # fail open: no helper, no gate
    sys.exit(0)
HEREDOC_BODY = es.HEREDOC

HOME = Path.home() / ".claude"
STATE = Path(os.environ.get("TEST_GATE_STATE") or HOME / "state" / "test-gate")
LOG = Path(os.environ.get("TEST_GATE_LOG") or HOME / "test-gate.log")
MARK_TTL = 14 * 86400

# Commands are judged by what each segment STARTS with, never by words found
# anywhere in the text: 'pip install pytest', 'grep jest' and a commit message
# naming app.ts all mention a runner or a file without running anything.
# Segments are split on shell operators OUTSIDE quotes, so a commit message
# like "x; pytest passes now" stays one argument.
OPERATORS = {"&&", "||", ";", "|", "&", "(", ")", ";;", "|&", "\n"}
KEYWORDS = {"do", "then", "if", "while", "until", "elif", "else", "!", "{", "time", "nohup",
            "exec", "command", "rtk", "proxy", "xargs"}
VALUE_FLAGS = {"-u", "-g", "-C", "-h", "-p", "-U", "-D"}
ASSIGN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
ALWAYS = {"pytest", "jest", "vitest", "tsc", "mocha", "rspec", "playwright", "phpunit",
          "gradle", "gradlew", "mvn", "make", "ctest", "hooks-smoke-test.sh"}
SUBCOMMANDS = {
    "go": {"test", "build", "run", "vet"}, "cargo": {"test", "build", "run", "check"},
    "dotnet": {"test", "build", "run"}, "swift": {"test", "build", "run"},
    "deno": {"test", "run"}, "ng": {"test", "build", "serve"},
    "helm": {"template", "lint", "install", "upgrade"},
    "docker": {"run"}, "docker-compose": {"up"},
}
PACKAGE = {"npm", "pnpm", "yarn", "bun"}
WRAPPERS = {"uv", "poetry", "pipenv", "hatch", "pdm", "rye"}
# Package-manager subcommands that manage packages rather than run code.
NOT_RUNS = {"lint", "format", "fmt", "prettier", "install", "i", "add", "remove", "rm",
            "uninstall", "outdated", "audit", "ci", "ls", "list", "view", "config", "init",
            "publish", "login", "whoami", "cache", "pack", "version", "info", "why",
            "update", "upgrade", "link"}
INTERPRETERS = {"python", "python3", "node", "bash", "sh", "zsh", "bun", "tsx", "ts-node",
                "deno", "ruby", "perl", "php", "osascript"}
LOCAL = re.compile(r"\b(localhost|127\.0\.0\.1|0\.0\.0\.0)\b")
TEST_NAME = re.compile(r"^(test_.+|.+_test\.\w+|.+\.(test|spec)\.\w+|test)$")
# Inline scripts write files without a redirect the edit scanner can see. They
# count as edits only when the script visibly writes; most of them only read.
INLINE = re.compile(r"\b(python3?|node|ruby)\s+(-\s*)?(<<|-c\b|-e\b)|\bperl\b[^|;&\n]*\s-\w*i\w*\b")
WRITES = re.compile(r"write_text\(|write_bytes\(|\.write\(|open\([^)]*['\"][wa]b?\+?['\"]"
                    r"|writeFileSync|writeFile\(|\bperl\b")
VERIFY_SKILLS = ("done", "run", "demo-qa", "verification-before-completion")


def log(line: str) -> None:
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        with LOG.open("a") as fh:
            fh.write(f"{time.strftime('%F %T')} {line}\n")
    except OSError:
        pass


def segments(body: str) -> list:
    """Token lists, one per simple command, split on operators outside quotes."""
    try:
        lex = shlex.shlex(body, posix=True, punctuation_chars=";&|()\n")
        lex.whitespace = " \t\r"
        lex.whitespace_split = True
        lex.commenters = ""
        toks = list(lex)
    except ValueError:
        # Unbalanced quotes: fall back to a plain split. Worst case is one
        # missed or extra run in a command that would not parse anyway.
        return [s.split() for s in re.split(r"&&|\|\||[;|\n()]", body)]
    out, cur = [], []
    for t in toks:
        if t in OPERATORS or set(t) <= set(";&|()\n"):
            out.append(cur)
            cur = []
        else:
            cur.append(t)
    out.append(cur)
    return out


def strip_prefix(toks: list) -> list:
    i = 0
    while i < len(toks):
        t, b = toks[i], os.path.basename(toks[i])
        if ASSIGN.match(t) or b in KEYWORDS:
            i += 1
        elif b == "timeout":
            i += 1
            while i < len(toks) and toks[i].startswith("-"):
                i += 1
            if i < len(toks) and toks[i][:1].isdigit():
                i += 1
        elif b in ("sudo", "env"):
            i += 1
            while i < len(toks) and (toks[i].startswith("-") or ASSIGN.match(toks[i])):
                i += 2 if toks[i] in VALUE_FLAGS else 1
        else:
            break
    return toks[i:]


def is_test_path(arg: str) -> bool:
    return bool(TEST_NAME.match(os.path.basename(arg))) or "tests/" in arg or "/test/" in arg


def segment_runs(toks: list, changed: set, loops: set) -> bool:
    toks = strip_prefix(toks)
    if not toks:
        return False
    head, args = os.path.basename(toks[0]), toks[1:]
    first = args[0] if args else ""
    if head in ALWAYS:
        return True
    if head in SUBCOMMANDS:
        if head == "docker" and first == "compose":
            return "up" in args
        return first in SUBCOMMANDS[head]
    if head == "kubectl":
        return any(a in ("apply", "exec", "rollout") for a in args)
    if head in WRAPPERS:
        return first == "run" and segment_runs(args[1:], changed, loops)
    if head in PACKAGE:
        if not first or first.startswith("-") or first in NOT_RUNS:
            return False
        if first == "run":
            return len(args) > 1 and args[1].split(":")[0] not in NOT_RUNS
        return head != "bun" or first in ("test", "run", "x")
    if head in ("npx", "bunx", "pnpx"):
        return bool(first) and not first.startswith(("prettier", "eslint", "biome", "-"))
    if head in ("curl", "wget", "http", "xh"):
        return any(LOCAL.search(a) for a in args)
    if head in INTERPRETERS:
        if "--test" in args:
            return True
        if "-m" in args:
            k = args.index("-m")
            return k + 1 < len(args) and args[k + 1] in ("pytest", "unittest")
        script = next((a for a in args if not a.startswith("-")), "")
        if script.strip("${}\"") in loops:
            return True
        return bool(script) and script != "-" and (
            is_test_path(script) or os.path.basename(script) in changed)
    if "/" in toks[0] or head.endswith((".sh", ".py", ".js", ".mjs", ".ts", ".rb")):
        return is_test_path(toks[0]) or head in changed
    return False


def runs_code(command: str, edited: set) -> bool:
    """True when some segment of a Bash command exercises code. Heredoc bodies
    are data, so they are removed before looking."""
    changed = {os.path.basename(p) for p in edited}
    segs = segments(HEREDOC_BODY.sub(" ", command))
    # 'for t in tests/*.sh; do bash "$t"; done': the loop variable stands for
    # test scripts, so running it counts.
    loops = {s[1] for s in segs if len(s) > 3 and s[0] == "for" and s[2] == "in"
             and any(is_test_path(a) or os.path.basename(a) in changed for a in s[3:])}
    return any(segment_runs(s, changed, loops) for s in segs)


def order_key(stamp: str, seq: int):
    # '...:00Z' must sort before '...:00.500Z'; as plain text it sorts after.
    if stamp.endswith("Z") and "." not in stamp[-6:]:
        stamp = stamp[:-1] + ".000Z"
    return (stamp, seq)


def scan(lines, edited: set, es, counter: list):
    """Returns events as (kind, order_key, command, tool_use_id) and adds the
    files that were really changed to `edited`. A failed edit changed nothing,
    so errored edits are dropped. A failed TEST still ran the code, so errored
    runs are kept."""
    events, errored, writes = [], set(), {}
    src_token = re.compile(r"[\w./~-]+(?:" + "|".join(re.escape(e) for e in es.SOURCE) + r")(?![\w])")

    def add(kind, stamp, command="", tid="", paths=()):
        counter[0] += 1
        events.append((kind, order_key(stamp, counter[0]), command, tid))
        if kind == "edit":
            writes[counter[0]] = (tid, paths)

    for raw in lines:
        try:
            entry = json.loads(raw)
        except (ValueError, TypeError):
            continue
        if not isinstance(entry, dict):
            continue
        message = entry.get("message")
        content = message.get("content") if isinstance(message, dict) else None
        if not isinstance(content, list):
            continue
        stamp = str(entry.get("timestamp") or "")
        for block in content:
            if not isinstance(block, dict):
                continue
            if block.get("type") == "tool_result" and block.get("is_error"):
                errored.add(block.get("tool_use_id"))
                continue
            if block.get("type") != "tool_use":
                continue
            name, data, tid = block.get("name") or "", block.get("input") or {}, block.get("id") or ""
            if not isinstance(data, dict):
                continue
            if name in es.EDITORS:
                path = es.qualifies(data)
                if path:
                    add("edit", stamp, "", tid, (path,))
            elif name == "Bash":
                command = str(data.get("command") or "")
                wrote = [t for t in es.shell_targets(command) if es.qualifies({"file_path": t})]
                if INLINE.search(command) and WRITES.search(command):
                    wrote += [t for t in src_token.findall(command) if es.qualifies({"file_path": t})]
                # The write is ordered before anything the same call runs, so
                # 'patch && run the tests' in one command counts as tested.
                if wrote:
                    add("edit", stamp, "", tid, tuple(wrote))
                add("bash", stamp, command, tid)
            elif name.endswith("__navigate") and LOCAL.search(str(data.get("url") or "")):
                add("run", stamp, "", tid)
            elif name == "Skill":
                skill = str(data.get("skill") or "").split(":")[-1]
                if skill in VERIFY_SKILLS:
                    add("run", stamp, "", tid)
    kept = []
    for event in events:
        if event[0] == "edit":
            tid, paths = writes[event[1][1]]
            if tid and tid in errored:
                continue
            edited.update(paths)
        kept.append(event)
    return kept


def main(payload: dict) -> str:
    if payload.get("stop_hook_active"):
        return "PASS stop-hook-active"
    session = str(payload.get("session_id") or "").strip()
    transcript = str(payload.get("transcript_path") or "")
    if not session or not transcript:
        return "PASS no-session-or-transcript"
    safe = re.sub(r"[^A-Za-z0-9_-]", "", session)
    mark = STATE / f"{safe}.blocked"
    if mark.exists():
        return "PASS blocked-once-already"
    edited: set = set()
    events = []
    counter = [0]
    try:
        with open(transcript, errors="replace") as fh:
            events += scan(deque(fh, maxlen=4000), edited, es, counter)
    except OSError:
        return "PASS transcript-unreadable"
    folder = Path(transcript[:-6] if transcript.endswith(".jsonl") else transcript) / "subagents"
    try:
        subs = sorted(folder.glob("*.jsonl"), key=lambda f: f.stat().st_mtime)[-40:]
    except OSError:
        subs = []
    for sub in subs:
        try:
            with sub.open(errors="replace") as fh:
                events += scan(fh, edited, es, counter)
        except OSError:
            continue
    if not edited:
        return "PASS no-source-edits"
    last_edit = max((k for kind, k, _, _ in events if kind == "edit"), default=("", 0))
    last_run = max((k for kind, k, c, _ in events
                    if kind == "run" or (kind == "bash" and runs_code(c, edited))), default=("", 0))
    if last_run[0] and last_run > last_edit:
        return f"PASS ran-after-edits files={len(edited)}"
    try:
        STATE.mkdir(parents=True, exist_ok=True)
        for old in STATE.glob("*.blocked"):
            if old.stat().st_mtime < time.time() - MARK_TTL:
                old.unlink()
        # O_EXCL so two parallel stops produce one block, not two.
        os.close(os.open(mark, os.O_CREAT | os.O_EXCL | os.O_WRONLY))
    except FileExistsError:
        return "PASS blocked-once-already"
    except OSError:
        return "PASS marker-unwritable"
    return f"BLOCK {len(edited)}"


def run() -> int:
    skip = f"{os.environ.get('CLAUDE_SKIP_HOOKS', '')},{os.environ.get('OMC_SKIP_HOOKS', '')}"
    if "test-gate" in skip.split(","):
        return 0
    if os.environ.get("CLAUDE_CODE_ENTRYPOINT", "cli") not in ("cli", "claude-vscode", "claude-desktop", "claude-desktop-3p"):
        return 0
    try:
        payload = json.loads(sys.stdin.read() or "{}")
        verdict = main(payload)
    except Exception as exc:  # fail open
        payload, verdict = {}, f"PASS internal-error={type(exc).__name__}"
    log(f"{verdict} session={payload.get('session_id') or '?'}")
    if not verdict.startswith("BLOCK"):
        return 0
    n = verdict.split(" ")[1]
    print(f"TEST GATE: {n} source file(s) changed this session and nothing has run them "
          "since the last change. Run the tests, the build, or the changed code itself, "
          "and read the result before saying it works. If it truly cannot be run here, "
          "say so plainly in your reply. Fires once per session; the next stop passes.",
          file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(run())
