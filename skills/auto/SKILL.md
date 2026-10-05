---
disable-model-invocation: true
name: auto
description: >
  The switch that makes the session keep working instead of handing back. While auto is
  on, any judgment question (which of two approaches, an ambiguous requirement, a
  preference with no correct answer) gets picked rather than put to the user, AND the end of
  a turn is not the end of the work: the session walks the ladder and takes the next
  rung. Anything irreversible, outward-facing or money-shaped still stops and asks,
  always.

  `/auto away` is the same thing unattended, with a much larger carry-on allowance, a run
  log and the reboot discipline.

  Triggers: "/auto", "auto on", "auto mode", "you decide", "you pick", "just decide",
  "stop asking me", "decide for me", "I don't know, you choose", "use best practice".

  Do NOT use when the user wants to steer step by step (that is `carryon`), and never to
  approve a plan, approve a code review, or self-approve anything.
metadata:
  user-invocable: true
  slash-command: /auto
  proactive: false
---

# auto: it decides, you stop being asked

the user is asked judgment questions he has no basis to answer. The interruption costs more
than a reversible wrong pick would. This skill flips a per-session switch that stops the
asking and starts the deciding.

`carryon` is the opposite mode: the user is watching, so it stops on a decision. `auto` is for
when he is not, or when the question is not his to answer.

## The switch

Run the matching command. It writes this session's switch and prints one line.

| You typed | Run |
|---|---|
| `/auto`, "you decide", "stop asking me" | `python3 ~/.claude/hooks/auto-mode.py --on` |
| `/auto away`, "afk", "I'm going out" | `python3 ~/.claude/hooks/auto-mode.py --on away` then run section 3 |
| `/auto off` | `python3 ~/.claude/hooks/auto-mode.py --off` |
| `/auto status` | `python3 ~/.claude/hooks/auto-mode.py --show` |

The switch is per session and dies with it. There is no global default, deliberately.
After a `/clear` it needs flipping again. If a `/reboot` handoff is written while auto is
on, note that in the handoff so the next session knows to flip it back.

`~/.claude/hooks/auto-mode.py` is the enforcement, not this file. It denies the
`AskUserQuestion` tool while the switch is on, and it blocks the end of a turn while
there is a rung left, so both halves keep working at high context where a written rule
would have stopped firing.

The second half is the one that was missing until 21 Aug 2026. Across twelve sessions
with auto on, the model almost never asked a question: it wrote a status report and
ended the turn, and the user restarted it by hand with "carry on /auto" and "ok go". Nothing
watched the end of a turn, so nothing fired. It does now, in both modes.

## 1. How to decide

> Pick the reversible option. Prefer the one that adds no new dependency. Prefer the
> conventional choice over the clever one.

Then say it in **one line** and keep going:

```
Picked flat config over nested: reversible, no new file layout to unpick later.
```

Not a paragraph, not a table, not a request for confirmation. the user reads the line as it
scrolls past and overrides on the spot if he disagrees. That visibility is the whole
safety mechanism, so never make a call silently.

`/auto status` lists the calls taken so far this session.

## 1.5 How to keep going

The end of a turn is not the end of the work. Before handing back, walk this ladder and
take the FIRST rung with a real candidate.

1. **Broken beats new.** Failing build, typecheck, lint or test on the current branch.
   Nothing else matters while red.
2. **Unblock beats build.** Something a person or a queued job is waiting on: a review
   comment, CI failing on an open PR, a merge conflict.
3. **Finish beats start.** In-flight incomplete work: uncommitted diff, half-written
   function, a stub, a `TODO` this session left, a `test.skip`. Placeholders are blockers,
   not progress. Implement them or report them.
4. **Verify beats claim.** A change asserted done but never driven, so exercise the real
   flow (`run` skill), not just green tests. Tests passing is not the same as it working.
5. **Ship beats polish.** Verified committed work sitting unpushed gets pushed. A pushed
   branch with no PR gets one.
6. **Then, and only then, the next planned item** from the plan, task list or handoff.

Inventing plausible busywork is the failure mode: refactors nobody asked for, speculative
tests, defensive rewrites. If you cannot name the rung an action came from, it is not an
action.

**To stop instead**, the ladder must be empty, or the next rung must be one of the things
in section 2. Then end the reply with a line starting `STOPPED:` and one clause saying
what you need. That line is honoured immediately and never argued with, and it resets the
allowance. Without it the hook assumes the turn ended by accident and pushes back.

The allowance is 3 carry-ons per message the user sends when he is watching, 12 in away mode.
Ending a turn with the same text twice counts as wedged and hands back regardless.
`/auto status` shows how much of the allowance is used.

## 2. What still stops and asks

The hook lets these through untouched, and you must stop on them even if the hook misses:

- **Irreversible or outward-facing:** deploy, prod, DB migration or schema change,
  force push, `rm` of anything untracked, merging to main, dismissing a reviewer's active
  CHANGES_REQUESTED, and anything sent to a person.
- **Protected paths:** `.env*`, lockfiles, credentials, schema files.
- **Money:** payments, invoices, subscriptions, anything with a price on it.
- **Approval:** never approve your own plan, never approve your own code review. Writing
  and reviewing stay separate passes.
- **Same action failed twice** (hand to `/codex:rescue`), **15 minutes with no forward
  progress**, or **a credential you do not have**.

The test: if guessing wrong wastes an hour, decide it. If guessing wrong is unrecoverable
or touches someone else, stop.

**Escape hatch.** If the hook blocks a question that genuinely belongs to the user, say so in
one line, then ask the identical question again on your NEXT turn, after he has replied.
A repeat on a later turn is always allowed through. A repeat in the same breath is not:
that reads as not having absorbed the answer rather than insisting, and it used to let
roughly every second blocked question straight back out.

## 3. `/auto away`: the unattended run

Everything above still applies. This section adds the engine that keeps working after
the user's last message.

### 3.0 Gate

**Assert you are not in plan mode.** If you are, stop and print exactly one line:

```
auto away needs write access. Shift+Tab to auto, or relaunch: claude --permission-mode auto
```

the user's global default is plan mode. A subagent with no explicit `permissionMode` inherits
the parent, so a run started from a plan-mode session is read-only and will do nothing
while appearing to work.

Then record the start time. The 4h cap and the 15-minutes-stuck rule both apply.

### 3.1 Orient (cheap, once per run, not per iteration)

Run in parallel, read only what you need:

- `git status --short --branch` and `git log --oneline -10`
- `gh pr list --author @me --json number,title,reviewDecision,statusCheckRollup` (if a remote exists)
- Latest `.omc/handoffs/*` or `~/.claude/reboots/*` for this cwd, if present
- Any in-flight task list, plan file (`.omc/plans/`), or TODO left by this session

**Assert location before the first edit.** Confirm `git branch --show-current` is the
intended branch. Mismatch means fix location first, never edit past it. On the default
branch, branch before editing.

### 3.2 Pick ONE action, fixed ladder, top match wins

The ladder in section 1.5, unchanged. Take the first rung with a real candidate, do not
skip up, do not batch. Nothing left means report and stop, on a `STOPPED:` line.

### 3.3 Do it

- Edit-heavy or multi-file goes to `executor` (`model=sonnet`, `opus` for judgment work).
  Every subagent prompt says: "return verdict plus max 5 bullets, no full body".
- 2 or more file edits means a failing test or an explicit assertion checklist BEFORE editing.
- External dependency (SSO, OAuth, third-party API, MDM, browser auth) means run the
  feasibility probe and name the fallback BEFORE building on it. No probe, no build.

### 3.4 Verify, then ship

Gate every action before it counts as done:

1. `done` skill: typecheck, lint, tests, build. Non-zero exit means not done, back to rung 1.
2. `run` skill: drive the actual change and observe it. Required for anything with a
   runtime surface. A green gate with a silent subagent behind it is the classic false pass.
3. Commit on the working branch. Push. **Push-verify:** confirm `git branch --show-current`
   matches the target, then confirm `git push` exited 0 and the output is not `up-to-date`
   or rejected before claiming it landed.
4. Branch has commits and no PR, so open one.
5. **Append one line to `.omc/auto/run-<timestamp>.md`** before moving on: rung, action,
   verify command, exit code, or the call you made and why. Create it on the first action.
   This is the only record of an unattended run and the closing report is generated from it.

### 3.5 Loop

Back to 3.2. Pace with the native self-paced loop (`/loop` with no interval) so ticks are
driven by what you are waiting on, not a fixed clock. Self-cancel on:

- Ladder empty
- Any hard stop from section 2
- 4h cap reached. Surface it as a usage leak and self-enforce it. Run Referee pauses at the
  same mark, but that is the backstop, not the primary control.
- **~20 tool calls or 50% context, whichever first.** Write a `/reboot` handoff naming
  state, next rung, verify command and whether auto was on, then stop the loop cleanly. Do
  not compact through it. Nobody is watching, so a rotted context runs unsupervised until
  it does damage.

### 3.6 Report, 4 lines, no more

```
DID:     <what changed> (<n> actions, rungs <x,y>)
GREEN:   <verify command> exit 0 · <PR #n | branch pushed | local only>
DECIDED: <n> calls · <one clause each, so he can reverse any of them>
NEXT:    <the rung-N action waiting> | STOPPED: <reason, and what you need from me>
```

Everything else goes in the log file. Name the log path on a fifth line only if something
failed. No summary tables, no per-file narration, no "let me know if".
