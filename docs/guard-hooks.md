---
title: Guard Hooks
nav_order: 10
parent: Advanced
---
# Guard Hooks: rules that cannot be argued with

A rule in `CLAUDE.md` is a request. The model reads it once and weighs it against everything else
in context, and the further a session runs the less it weighs. A hook is different: it runs in the
harness, outside the model, and can refuse a tool call outright.

The working principle in this setup: **"always" means a hook, "usually" means a skill.** Any rule
that was ignored for three sessions gets turned into a hook or deleted.

All the scripts below are in [`hooks/`](../hooks/). The full wiring is in
[`examples/settings.hooks.json`](../examples/settings.hooks.json) and every script is catalogued in
[`hooks/README.md`](../hooks/README.md).

## The recorder plus gate pattern

Most of these come in pairs. Nudges (a reminder injected into the prompt) were tried first and
failed: the model acknowledged them and carried on. What worked was a blocking pair:

- a **recorder** on `PostToolUse` that quietly notes when the right thing has happened, and
- a **gate** on `PreToolUse(Edit|Write)` that blocks the first edit until the recorder has seen it.

The gate's error message says exactly what to run to get unblocked. One command, then work carries
on. Nothing has to be remembered.

| Pair | What it forces | Why it exists |
|---|---|---|
| `probe-recorder` + `probe-gate` | Reach an external service once (an auth call, a curl) before writing code against it | Corporate SSO, passkeys and third-party MCPs killed whole sessions that a five-minute probe would have saved |
| `ui-state-recorder` + `ui-state-gate` | Query the live theme or variant before the first style edit in a visual QA session | About fifteen commits once chased a "parity bug" that was the page being judged in the wrong theme |
| `leg-scope --record` + `leg-scope --gate` | A continuation session states its own finish line (`leg-done: ...`) before editing | Sessions that inherit the project's goal end on context exhaustion instead of completion |
| `verify-gate --auto-arm` + `verify-gate` (Stop) | Records the typecheck error count at first edit; blocks ending the turn if it went up | "Done" claims on code that no longer compiled |
| `evidence-recorder` + `pr-claim-gate` | Every number in a PR body ("1216 passed") must match a recorded run | Five PRs blocked in one week for claims, not code |

## Other gates worth stealing

| Hook | Event | What it does |
|---|---|---|
| `branch-guard` | PreToolUse(Edit) | On the first edit to a repo, prints the live branch, dirty state and any other session in the same checkout |
| `mutation-proof-gate` | PreToolUse(Bash) | New tests must be shown to fail against broken code before the commit |
| `protect-paths` | PreToolUse(Edit) | Blocks edits to `.env`, lockfiles and credentials |
| `firewall` | PreToolUse(Bash) | Blocks commands that wait on stdin, open a pager, or look irreversible |
| `research-only-guard` | PreToolUse(Edit) | When the ask was research only, no file edits |
| `run-referee-guard` | PreToolUse | Honours the out-of-band watchdog's verdict (see [Session Lifecycle](session-lifecycle.md)) |

## Reply-shape hooks

Hooks can police the answer as well as the actions. `answer-shape-nudge` injects the reply rules on
every prompt (length budget, plain English, no em dashes), and `register-gate` and
`status-shape-gate` run on `Stop` and send a reply back if it breaks them. The lesson from building
these: **the rule set that repeats wins.** A plugin that injects a contradicting instruction later
in the same prompt will beat a beautifully written rule that only loads at session start.

## Costs

Every hook adds latency to the event it is on. Keep `PreToolUse` hooks fast (they block the call)
and push slow work into `PostToolUse` or `Stop`. Run a smoke test after editing any hook:
`hook-edit-smoke.sh` does this automatically when a hook file is saved.

## Escape hatch

Most gates honour `CLAUDE_SKIP_HOOKS=<hook-name>`, but only when it is set in the shell that
launched `claude`. A hook inherits the environment of the Claude Code process and nothing later:
an `export` typed inside a session, or the variable used as a prefix on one command, never reaches
it (this was measured, not assumed). For an in-session off switch, use a state file the hook reads,
the way `paste-guard.py` does with `/paste-guard off`.
