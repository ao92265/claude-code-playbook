---
name: retry
description: Resume and re-run the last task that failed because of a Claude API error or outage (overloaded/529, 500/503, rate limit, network drop, "Claude is down"). Use AFTER the error clears, when the user says "/retry", "retry", "try that again", "it errored, redo it", "pick up where you crashed", or "the API was down, continue". For surviving a live outage unattended, point them at the claude-retry wrapper script instead. Do NOT use to retry a task that failed on its own merits (bad logic, failing test) — that's a fix, not a retry.
---

# Retry After an API Error / Outage

A transient Anthropic API failure (overload, 5xx, rate limit, network blip, or a
full outage) aborts the turn mid-task. This skill cleanly resumes the work that
got cut off — it does NOT start fresh and does NOT re-litigate decisions already
made before the error.

## First: is this actually a retry?

Only proceed if the last failure was **infrastructure**, not the work itself:

- ✅ Retry: `Overloaded`, `429`/`529`, `500`/`503`, `rate_limit`, `fetch failed`,
  `socket hang up`, "Claude is down", the turn just stopped with no result.
- ❌ Not a retry — that's a fix: a test failed, a build broke, wrong output, a
  logic bug. Don't blindly redo it; diagnose. Say so and switch to fixing.

If it's ambiguous, ask the user which it was before acting.

## Procedure

1. **Reconstruct where it died.** Read the last few turns + any handoff/state
   (`.omc/state/`, `.omc/handoffs/`, todos, open files) to find the exact action
   that was in flight when the error hit. Don't assume — verify against the
   actual repo/file state, since a partial write may have landed.

2. **Check for partial work.** `git status --short` and inspect the target
   file(s). The failed action may have half-completed (a file written but not
   verified, a commit started). Reconcile before redoing, so you don't double-apply.

3. **Re-run only the cut-off action**, not the whole task. Pick up from the last
   verified-complete step. If several steps remain, restate the short remaining
   list first so the user can confirm scope.

4. **Verify end-to-end** before claiming done (build/test as the project
   requires) — the interruption means nothing downstream was checked.

## Surviving a LIVE outage (the wrapper)

This skill can't help while the API is actually down — the model isn't running to
invoke it. For that, use the shell wrapper, which relaunches the CLI with
exponential backoff and resumes via `--continue`:

```bash
~/.claude/scripts/claude-retry.sh [any normal claude args]
# e.g.  ~/.claude/scripts/claude-retry.sh -p "finish the migration"
#       ~/.claude/scripts/claude-retry.sh           # interactive TUI
```

It retries only transient failures (overload/5xx/rate-limit/network), backs off
4s→8s→16s… (capped), and stops immediately on auth/credit errors. Suggest a
shell alias for convenience:

```bash
alias claude-r='~/.claude/scripts/claude-retry.sh'
```

Tune via env: `CLAUDE_RETRY_MAX` (default 5), `CLAUDE_RETRY_BASE` (4s),
`CLAUDE_RETRY_CAP` (120s). Log at `~/.claude/claude-retry.log`.
