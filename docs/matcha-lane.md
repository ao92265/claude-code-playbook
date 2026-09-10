---
title: Matcha Lane
parent: Advanced
nav_order: 10
---
# Matcha Lane

Matcha is an internal, Anthropic compatible API gateway. The matcha lane runs the real Claude Code binary headless against it, so a delegated task gets a full agent with file access, not a single chat completion. Cost lands on the gateway account per token, not on your Claude subscription. It is read only by default, and `--write` opts it into editing files.

Three hooks sit around it: one reviews your working diff when a turn ends, one surfaces the findings and warns when your subscription quota is nearly gone, and one blocks cheap subagent spawns under quota pressure and points them at the gateway instead.

## What It Is

The [matcha skill](../skills/matcha/) wraps `matcha-run.sh`, a script that launches `claude` in restricted mode against the gateway with a bounded prompt, a budget cap, and a timeout. Same shape as the Codex delegation lane described in [Multi-Model Orchestration](multi-model-orchestration.md): send a bounded slice of work, keep working yourself, collect the answer when it lands. The model tier (fast, standard, deep) is picked automatically from whatever the gateway reports as current, never named from memory.

Because the run is a full agent, it can read, grep, and glob inside a working directory you point it at. With `--write` it can also edit and use a shell there, still confined to that directory.

## When To Reach For It

Use the lane, rather than doing the work in this session, when:

- You want a second, independent reviewer on a diff before calling something done.
- The task is bounded and mechanical enough to hand off with a short prompt (a review, a diagnosis, a bulk edit), and you would rather keep your own context for judgement and orchestration.
- Your subscription window is close to its limit and the task can be pushed off it onto the gateway instead.

It is the wrong tool for a one-line lookup (the plain `matcha "prompt"` command is cheaper, since it is a single API call with no tools), for anything the user specifically asked to send through Codex, and for work that needs this conversation's context, since the delegate starts with no memory of it.

## Read Only By Default, And Why That Matters

`matcha-run.sh` reads, greps, and globs inside the working directory and nothing else, unless `--write` is passed. This matters for two reasons:

1. A review or diagnosis has no reason to touch files. Keeping it read only means a mistake in the prompt cannot turn into an unwanted edit.
2. A `--write` run is real risk: it edits a real working directory. Before one runs, the directory should be a git checkout with current work committed or stashed, so the edits are reviewable as a diff and reversible, and it should never be pointed at a checkout another session is actively using.

The nested run also ignores your own hooks on purpose, because it launches in restricted mode. Without that, your hooks would fire inside the delegate and block its own allowed tools.

## The Three Hooks

| Hook | Point | What it does |
|------|-------|---------------|
| [matcha-review.sh](../hooks/matcha-review.sh) | `Stop` | When a turn ends, sends the working diff to the gateway for an independent, read only review, in the background. Skips diffs that are too small to be worth it or too large for the delegate to hold, keeps a daily spend ceiling, and never blocks the stop. |
| [matcha-surface.sh](../hooks/matcha-surface.sh) | `UserPromptSubmit` | On your next prompt, delivers any review that finished since the last one, and checks your subscription usage. If the window is nearly spent it tells you to route heavy work through the gateway instead of doing it here. |
| [matcha-offload-gate.sh](../hooks/matcha-offload-gate.sh) | `PreToolUse` on `Agent` | Under real quota pressure, blocks a cheap subagent spawn (Haiku or Sonnet tier) and points the caller at `matcha-run.sh` instead, so mechanical subagent work stops competing with the session for what is left of the subscription window. Fails open on any error, and can be bypassed with `MATCHA_OFFLOAD_OK=1`. |

## Honest Limits

The two quota aware hooks, `matcha-surface.sh` and `matcha-offload-gate.sh`, only work if something outside Claude Code is writing a usage sampler file (a record of how much of the five hour and seven day subscription window has been used). Claude Code does not ship that sampler. Without it, both hooks read nothing, find nothing, and exit quietly: no warning, no gate, no error. They are not broken in that state, they are simply inert, and nothing in a normal session will tell you that.

`matcha-review.sh` has no such dependency: it only needs a git repository and a working diff, so it runs on its own once installed.

## See Also

- [Multi-Model Orchestration](multi-model-orchestration.md), for the Codex delegation lane this one is modelled on.
- [Cost and Observability](cost-and-observability.md), for tracking what a delegate run actually costs.
