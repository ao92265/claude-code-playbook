---
name: done
description: >
  Single-command verification gate. Runs typecheck + lint + tests + build before
  any "done"/"complete" claim. Refuses to print a green summary on any non-zero
  exit code. Use before saying a task is finished, before committing, or before
  handing back to the user. Triggers: "/done", "verify done", "ready to commit",
  "finished implementing".

  Auto-detects the repo: if package.json declares a `ci:local` script, it runs
  that. Otherwise falls back to `tsc + lint + test` discovery.

  Do NOT use this skill for: mid-task partial verification (use the agent's own
  judgment), exploration, or one-file edits where the boundary check isn't
  warranted yet.
metadata:
  user-invocable: true
  slash-command: /done
  proactive: true
---

# Done — Verification Gate

A "done" claim without a verification command and exit code is a guess. This
skill makes the gate mechanical.

## Protocol

1. **Detect entrypoint.** From the repo root:
   - If `jq -e '.scripts."ci:local"' package.json` succeeds → run `npm run ci:local`.
   - Else discover available scripts: `typecheck`, `lint`, `test`, `build`. Run
     them in that order. Skip silently if a script does not exist.
   - For monorepos with `frontend/` and `backend/` workspaces (Wraith pattern):
     also run the frontend variants (`typecheck:frontend`, `lint:frontend`,
     `test:frontend`).

2. **Capture exit code per stage.** Print one line per stage:
   ```
   [done] typecheck: exit=0
   [done] lint:      exit=0
   [done] test:      exit=1   <- failure
   ```

3. **Refuse green summary on any failure.** If any stage exits non-zero:
   - Print the failing stage's last 30 lines of output.
   - Print `STATUS: FAIL — do not claim done.`
   - Do NOT commit, push, or mark the task complete.

4. **On full pass:** print `STATUS: PASS — all gates green.` Then proceed with
   whatever the user asked next (commit, PR, summary, etc.).

## Reference — Wraith Repo Specifics

`/path/to/your-project` exposes `npm run ci:local` which expands to:

```
npm run lint && npm run typecheck && npm run test:backend \
  && npm run lint:frontend && npm run typecheck:frontend \
  && npm --prefix frontend run test:run
```

This is the preferred entrypoint there. `frontend/src/generated/` is excluded
by lint-staged via `--ignore-pattern`; the skill inherits that — it only runs
project scripts and does not file-walk.

## Hard Rules

- Run from the repo root. If you're in a subdirectory, `cd` to root first.
- Never silence non-zero exits with `|| true` or `2>/dev/null`.
- Long stages (build, full test) → use `run_in_background` and `Monitor`. Don't
  poll with sleep loops.
- If `npm install` is needed first, that's a different skill (`/check-env`). Do
  not auto-install dependencies.

## When Not To Run

- The user asked a research-only or exploratory question.
- You haven't actually made any changes this turn.
- A specific narrower check was requested (e.g. "just typecheck").

## Why This Skill Exists

The `/insights` report (2026-04-27) flagged "premature completion claims" as
the #1 recurring friction across 82 sessions. Existing prose rules in CLAUDE.md
("verify before claiming done") were not enough — Claude declared done with
failing tsc/vitest 3–4 times per cycle. This skill replaces the prose with a
mechanical gate.
