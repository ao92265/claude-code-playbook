#!/usr/bin/env python3
"""explainer-gate.py - PreToolUse (Edit|Write|MultiEdit): explain a folder before editing it.

The first edit to an existing source file in a folder, per session, is blocked once.
The block asks for a short plain explainer of that slice, written from the current
code. The edit goes through once an assistant message after the block contains a line
starting "Explainer:" plus real content. From Anthropic's "how the Claude Code team does code review"
(15 Oct 2026): understanding the slice first is what keeps an edit from breaking it.

Checked, not trusted: retrying without writing the explainer is blocked again. After
two blocks on the same folder it gives up and allows, so it can never trap a session.

Skips: new files, docs and config, memory and scratch paths, subagents (they carry the
parent's session id but write to their own transcript, so they could never satisfy it).
Fails open on any error. Disable for one launch: CLAUDE_SKIP_HOOKS=explainer-gate.
"""
import fcntl
import json
import os
import re
import sys

SKIP_EXT = (".md", ".mdx", ".txt", ".json", ".jsonl", ".yml", ".yaml", ".toml", ".lock",
            ".csv", ".svg", ".png", ".jpg", ".gif", ".plist", ".ini", ".cfg", ".env")
HOME = os.path.expanduser("~")
SKIP_PREFIX = ("/tmp/", "/private/tmp/", "/private/var/folders/", "/var/folders/",
               os.path.join(HOME, ".claude", "projects") + "/",
               os.path.join(HOME, ".claude", "handoffs") + "/",
               os.path.join(HOME, ".claude", "plans") + "/")
SKIP_PART = ("/.omc/", "/node_modules/", "/.git/", "/dist/", "/build/")
MAX_BLOCKS = 2
# "Explainer:" then real content. Narrating the block ("Explainer gate fired") must not pass.
EXPLAINED = re.compile(r"(?im)^\W*explainer\W*:\s*\S.{60,}")


def skip_file(path):
    if not path or not os.path.isfile(path):
        return True
    low = path.lower()
    if low.endswith(SKIP_EXT) or os.path.basename(low).startswith(".env"):
        return True
    return path.startswith(SKIP_PREFIX) or any(p in path for p in SKIP_PART)


def explained_since(transcript, line_no):
    """True if an assistant text after transcript line `line_no` has an Explainer line."""
    try:
        with open(transcript) as f:
            for i, line in enumerate(f):
                if i < line_no or '"assistant"' not in line:
                    continue
                try:
                    d = json.loads(line)
                except ValueError:
                    continue
                if d.get("type") != "assistant":
                    continue
                for c in (d.get("message") or {}).get("content") or []:
                    if isinstance(c, dict) and c.get("type") == "text" and EXPLAINED.search(c.get("text") or ""):
                        return True
    except OSError:
        pass
    return False


def line_count(path):
    try:
        with open(path, "rb") as f:
            return sum(1 for _ in f)
    except OSError:
        return 0


def main():
    if "explainer-gate" in os.environ.get("CLAUDE_SKIP_HOOKS", "").split(","):
        return 0
    try:
        p = json.load(sys.stdin)
    except ValueError:
        return 0
    if p.get("agent_id"):
        return 0
    path = (p.get("tool_input") or {}).get("file_path") or ""
    sid = p.get("session_id") or ""
    transcript = p.get("transcript_path") or ""
    if not sid or skip_file(path):
        return 0
    folder = os.path.dirname(os.path.abspath(path))

    state_dir = os.environ.get("EXPLAINER_STATE") or os.path.join(HOME, ".claude", "hooks", ".omc", "explainer")
    os.makedirs(state_dir, exist_ok=True)
    state_file = os.path.join(state_dir, re.sub(r"[^A-Za-z0-9_-]", "_", sid) + ".json")
    # Parallel Edit calls run this hook concurrently: lock the read-modify-write.
    lock = open(state_file + ".lock", "w")
    fcntl.flock(lock, fcntl.LOCK_EX)
    try:
        with open(state_file) as f:
            state = json.load(f)
    except (OSError, ValueError):
        state = {}
    entry = state.get(folder) or {}
    if entry.get("done"):
        return 0
    if entry and explained_since(transcript, entry.get("at_line", 0)):
        entry["done"] = True
    elif entry.get("blocks", 0) >= MAX_BLOCKS:
        entry["done"] = True
        entry["gave_up"] = True
    else:
        if not entry:
            entry = {"at_line": line_count(transcript), "blocks": 0}
        entry["blocks"] = entry.get("blocks", 0) + 1
    state[folder] = entry
    tmp = f"{state_file}.{os.getpid()}.tmp"
    with open(tmp, "w") as f:
        json.dump(state, f)
    os.replace(tmp, state_file)
    if entry.get("done"):
        return 0

    rel = folder.replace(HOME, "~", 1)
    print(f"explainer-gate: first edit in {rel} this session. Before you edit, read the "
          "current code and write a short plain explainer in your reply, on a line "
          "starting 'Explainer:'. Cover what this folder does, what the code you are about "
          "to change does and who calls it, and one thing that breaks if the edit is "
          "wrong. Write it from the code as it is now, not from memory. Then retry the "
          "same edit.", file=sys.stderr)
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        sys.exit(0)
