---
name: multiask
description: Cross-check an answer across 4 AI CLIs in parallel with an adversarial review pass. Expensive (about 1M tokens, 30 to 65s per call). Explicit invoke only: /multiask.
---

# /multiask — Parallel multi-CLI fan-out with adversarial review

Runs `act fanout` to dispatch the user's prompt across every installed AI coding CLI
in parallel, then runs a Claude-driven review gate on the outputs.

Backend: `agent-control-tower` at `~/Repos/agent-control-tower/`.
CLI entrypoint: `act fanout <prompt> [flags]`.
Playbook: `~/Repos/project-a/docs/guides/MULTIASK_PLAYBOOK.md`.

## When you fire this skill

1. First, decide whether auto-triggering is actually warranted using the strict rules
   in the description. If the question is not clearly in categories (a)-(d), DO NOT
   fire. Answer directly, or run `act fanout` against a single runtime.

2. If firing, announce it briefly BEFORE running so the user can interrupt:
   > "This looks security-critical — firing /multiask --adversarial to cross-check.
   > ~1 min and ~1M tokens. Say 'skip' to cancel."
   Then run `act fanout`.

3. Default to `--review adversarial` when auto-triggering. The whole point of
   auto-trigger is high-stakes questions where inferior answers cost you.

## How to invoke

Use the Bash tool to run:

```
act fanout "<user's prompt>" --review adversarial --runtimes claude,codex,gemini,copilot
```

`kiro-cli` is intentionally excluded from the default set — it is not installed
(`which kiro-cli` fails), so including it burns one guaranteed-REJECT slot.

Optional flags:
- `--runtimes codex,gemini` — explicit subset (omit any runtime you don't want)
- `--timeout 5` — per-runtime timeout (default 10m)
- `-C <path>` — working directory (default cwd)

The command prints the verdict.md path on exit. Read it with the Read tool and
present it inline to the user. If the command exits non-zero, show stderr and stop.

## Reading the verdicts: the minority is the point

Anthropic's multiagent work (Frontier Red Team, 13 Aug 2026) found two failures that this
skill exists to avoid, and one it can still fall into.

- **Clones agree with each other, not with reality.** Agents given the same context make
  the same wrong call at the same moment. Four genuinely different models is the defence,
  which is why this skill exists at all. If you ever fan out to several lanes of the SAME
  model, give each lane a different job (find the flaw, find the missed requirement, find
  the cheaper option, check it actually reproduces). Never send one prompt N times.
- **Consensus swallows the decisive fact.** In their hidden-profile test, groups voted for
  the wrong answer while one member held the fact that settled it. So when one engine
  dissents, report the dissent and what it saw. Do not average it away, do not describe
  the outcome as "three of four agreed" and leave it there. Say what the fourth saw and
  whether it is checkable.

## Known limitations

- Claude runtime often REJECTs in its own host session due to SessionStart hook noise.
  If you see claude REJECT with "hook noise" reason, that's expected, not a bug.
- Copilot uses the standalone `copilot` CLI with `--allow-all-tools`, not `gh copilot`.
  Requires `gh auth login` once for GitHub auth underneath.
- See the playbook for full troubleshooting and observed timings.

## When NOT to fire

If you are at all unsure, do one of:
- Run `act fanout "<prompt>" --runtimes codex` (or one other runtime) for a single-provider
  answer at roughly one-tenth the cost. The old `/ask` skill was removed with OMC on
  17 Aug 2026; this is its replacement.
- Answer directly from your own reasoning
- Ask the user "do you want me to cross-check with /multiask?"

Never fire `/multiask` twice for the same user turn. If adversarial review rejected
all engines, report that honestly and ask the user how to proceed — don't retry.
