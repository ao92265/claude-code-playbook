---
name: research-only
description: >
  Enforce strict research-only / analysis-only mode. When invoked, Claude MUST NOT use
  Edit, Write, MultiEdit, or NotebookEdit tools — findings are delivered as markdown only.
  Use when the user says "research-only", "analysis-only", "don't change code, just
  investigate", or at the start of a BMAD/ralph research phase.

  Do NOT use this skill for: implementation tasks, bug fixes, or any work where code
  changes are expected.
metadata:
  user-invocable: true
  slash-command: /research-only
  proactive: false
---

# Research-Only Mode

You are in strict research-only mode. The user wants findings, not changes.

## Hard Rules

1. **NEVER** use `Edit`, `Write`, `MultiEdit`, or `NotebookEdit`. Not once. Not "just this one small fix."
2. **NEVER** run Bash commands that mutate state: no `git commit`, `git push`, `npm install`, `rm`, `mv`, redirects (`>`, `>>`), or anything that writes to disk — except the sentinel-file ops in the next section, which are required.
3. Allowed tools only: `Read`, `Grep`, `Glob`, `WebFetch`, `WebSearch`, and read-only `Bash` (`git log`, `git diff`, `git status`, `ls`, `cat`, `gh pr view`, etc.).
4. Deliver findings **inline as markdown** in your response. Do not create report files unless the user explicitly asks.
5. Do **not** end your response with "want me to implement this?" or offer follow-up edits. Exit cleanly — the user will ask if they want implementation.

## Sentinel-File Enforcement (mechanical guarantee)

The `research-only-guard.sh` PreToolUse hook (registered in `~/.claude/settings.json`) blocks `Edit`/`Write`/`NotebookEdit` whenever the sentinel file exists. This makes the guarantee mechanical, not just prose.

**On entry to this skill** (very first action, before anything else):
```
mkdir -p .claude/state && touch .claude/state/research-only.flag
```

**On clean exit** (when the user explicitly ends research-only mode, or when the answer is delivered and the user is moving on):
```
rm -f .claude/state/research-only.flag
```

The flag is per-working-directory. If the user invokes the skill in a worktree, the flag lives in that worktree's `.claude/state/`. Do not write the flag at `~/.claude/state/` — the hook checks the CWD.

## Pre-response Checklist

Before sending your final response, confirm:
- [ ] I used zero Edit/Write/MultiEdit/NotebookEdit calls
- [ ] I ran zero state-mutating Bash commands
- [ ] My findings are delivered as markdown in the response
- [ ] I am not offering unsolicited implementation

## Why This Skill Exists

Past sessions had Claude violate explicit research-only constraints by reaching for `Edit` anyway, creating work to undo. This skill is a reminder, not a guarantee — if the user wants a mechanical guarantee, they should invoke Claude with `--disallowedTools "Edit,Write,MultiEdit,NotebookEdit"`.
