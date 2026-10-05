#!/usr/bin/env python3
"""UserPromptSubmit hook: surface relevant Obsidian vault notes for the current prompt.

Matches prompt keywords against the vault title index (titles.tsv, built by
~/.claude/scripts/vault-index.py); falls back to a filename scan if the index
is missing. Silent when nothing relevant. Never blocks: always exits 0.
"""
import json
import os
import re
import sys

VAULT = "~/Library/CloudStorage/OneDrive-example-corp/Work"
TITLES = os.path.expanduser("~/.claude/vault-index/titles.tsv")
MAX_RESULTS = 3
MIN_PROMPT_LEN = 15

# Generic English + dev vocabulary that would match noise, not domain notes.
STOPWORDS = {
    "this", "that", "with", "from", "have", "what", "when", "where", "which",
    "there", "here", "then", "than", "them", "they", "some", "into", "over",
    "about", "after", "before", "again", "also", "just", "like", "make",
    "made", "want", "need", "please", "should", "would", "could", "will",
    "your", "yours", "mine", "does", "done", "doing", "been", "being",
    "file", "files", "code", "codes", "line", "lines", "function", "class",
    "build", "builds", "error", "errors", "test", "tests", "testing", "run",
    "running", "fix", "fixes", "fixed", "bug", "bugs", "issue", "issues",
    "change", "changes", "changed", "update", "updates", "updated", "check",
    "checks", "work", "works", "working", "look", "looks", "looking",
    "write", "writes", "written", "read", "reads", "reading", "create",
    "created", "delete", "deleted", "remove", "removed", "setup", "config",
    "claude", "agent", "skill", "hook", "commit", "branch", "merge",
    "note", "notes", "vault", "obsidian", "search", "find", "help",
    "meeting", "meetings", "today", "yesterday", "tomorrow", "week",
    "index", "readme", "background", "semantic", "embedded", "completed",
    "project", "projects", "person", "type", "status", "active",
}

# Frozen/boilerplate content — fine for deep search, noise as always-on suggestions.
EXCLUDE_PATH_PARTS = ("Backup", "/Archive/", "Templates/", "/OLD/")


def tokens(text):
    words = re.findall(r"[a-z][a-z0-9-]{3,}", text.lower())
    return {w for w in words if w not in STOPWORDS}


def load_titles():
    rows = []
    if os.path.exists(TITLES):
        with open(TITLES, encoding="utf-8", errors="ignore") as f:
            for line in f:
                parts = line.rstrip("\n").split("\t")
                if len(parts) >= 2:
                    rows.append((parts[0], parts[1], parts[2] if len(parts) > 2 else ""))
        return rows
    # Fallback: filename scan (no index built yet)
    prune = {".obsidian", ".omc", "node_modules", "_archive-empty", ".trash"}
    for root, dirs, files in os.walk(VAULT):
        dirs[:] = [d for d in dirs if d not in prune]
        for f in files:
            if f.endswith(".md"):
                rel = os.path.relpath(os.path.join(root, f), VAULT)
                rows.append((rel, f[:-3], ""))
    return rows


def main():
    data = json.load(sys.stdin)
    prompt = (data.get("prompt") or "").strip()
    # skip slash commands, short prompts, and system-generated messages
    # (task notifications etc. arrive as XML-ish blocks, not user asks)
    if not prompt or prompt.startswith(("/", "<")) or len(prompt) < MIN_PROMPT_LEN:
        return
    toks = tokens(prompt)
    if not toks:
        return
    scored = []
    for rel, title, tags in load_titles():
        if any(part in rel for part in EXCLUDE_PATH_PARTS):
            continue
        hay = tokens(title + " " + tags + " " + os.path.basename(rel))
        score = len(toks & hay)
        if score:
            scored.append((score, rel, title))
    if not scored:
        return
    scored.sort(key=lambda s: -s[0])
    lines = [f"- {VAULT}/{rel} — {title}" for _, rel, title in scored[:MAX_RESULTS]]
    out = {
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": (
                "Possibly relevant Obsidian vault notes (background context — "
                "read only if actually relevant to the task):\n" + "\n".join(lines)
            ),
        }
    }
    print(json.dumps(out))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # a recall hook must never break prompt submission
    sys.exit(0)
