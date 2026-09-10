---
name: matcha
description: Delegate a bounded task to an agentic Claude run on the Harris Matcha gateway, the way the codex plugin delegates to Codex. Runs headless in the background, reads the repo, and with --write edits it, billed to Matcha per token instead of the user's subscription. Use when the user says "/matcha", "send it to matcha", "matcha this", "delegate to matcha", "second opinion from matcha", "have matcha review this", "run that on matcha", "offload this", or when the subscription is close to its limit and work can be pushed off it. Do NOT use for a one-line lookup (the plain `matcha "prompt"` command is cheaper), for image generation (that is imagegen), or as a substitute for a Codex review when the user specifically asked for Codex.
---

# Delegating to Matcha

Matcha is a Harris internal Anthropic passthrough. This skill runs the real
Claude Code binary headless against it, so the delegate is a full agent with
file access, not a single chat completion. Same rhythm as the Codex lane: send
a bounded slice, keep working, collect the answer.

Cost lands on the Harris Matcha account per token, not on your subscription.
That is the whole point, and also the reason every run is capped.

## The command

```
~/.claude/scripts/matcha-run.sh [--write] [--tier deep|standard|fast] \
  [--dir PATH] [--budget USD] [--timeout SEC] "task"
```

Read only by default. It can read, grep and glob inside the working directory
and nothing else. `--write` adds editing and shell, still confined to that
directory.

## Choosing the tier

The model is picked automatically: the script asks the gateway what is live
today and takes the newest generation in the tier's family. Never pass
`--model` unless the user names one. Never type a model id from memory, the
gateway reports a wrong name as a server error and the client retries it for
minutes before giving up.

| Tier | Family | Send it |
|------|--------|---------|
| `deep` (default) | Opus | review, diagnosis, architecture, anything needing judgment |
| `standard` | Sonnet | implementation, mechanical bulk edits, refactors |
| `fast` | Haiku | search, extraction, summarising a pile of files |

## How to run it

Run it in the background and carry on. Do not sit and watch it.

1. Confirm the working directory holds the code the task is about. The run
   cannot see outside it.
2. For a review or diagnosis, put the evidence where the delegate can read it.
   It has no shell in read mode, so a diff has to be written to a file in the
   working directory first, not fetched by the delegate.
3. Launch with `run_in_background`.
4. Collect when it lands. It prints the answer on stdout, and the cost, turn
   count and error flag on stderr.

## Writing the task

The delegate has no memory of this conversation. Everything it needs goes in
the prompt: what the code is for, what to look at, what a good answer looks
like. A bare "review this" gets a bare review.

Bound the output the same way subagent prompts are bounded: a verdict plus at
most five bullets, no full body. An unbounded prompt on Opus is how a delegate
costs a pound instead of five pence.

## Before a --write run

Writing is the mode that can hurt. Check both before launching:

- The working directory is a git checkout with the current work committed or
  stashed, so the delegate's edits are reviewable as a diff and reversible.
- The user asked for edits. If they asked for an opinion, a review or a
  diagnosis, stay read only.

Never point a write run at a shared checkout another session is using. Use a
worktree, the same rule as any other multi-session work.

## After a write run

Read the diff yourself before telling the user it is done. The delegate's report of
what it did is a claim, not evidence. Run the project's own checks.

## Gotchas

- **The nested run ignores your hooks on purpose.** It is launched in
  restricted mode, which skips the user and project settings files. Without
  that, your hooks fire inside the delegate and block its own allowed tools,
  which is what broke the earlier headless bots. Do not "fix" this by
  re-enabling them.
- **Bypass permissions is refused in restricted mode.** If a run dies
  immediately saying so, something is passing a permission mode through the
  environment. The script scrubs the inherited session variables for this
  reason.
- **`matcha` and `matcha-run.sh` are different things.** `matcha "prompt"` is
  one API call with no tools and a short cap, right for a quick question.
  This skill is the agentic one.
- **A killed run exits 124.** That is the wall clock cap, not a crash. The
  partial log path is on stderr.
- **No timeout command on this Mac.** The script carries its own watchdog, so
  do not wrap it in `timeout` or `gtimeout`, neither exists here.
