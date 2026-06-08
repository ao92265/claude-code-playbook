---
name: multiask
description: "Cross-check answer across 5 AI CLIs (claude/codex/gemini/copilot/kiro) in parallel + adversarial review. Auto-trigger only for high-stakes: security-critical code, prod incidents, scale architecture (over 1k RPS), irreversible decisions (DB migrations, breaking API changes). Or explicit /multiask. Cost ~1M tokens + 30-65s per call. Skip for normal coding, bug fixes, lookups, refactors."
---

# /multiask — Parallel multi-CLI fan-out with adversarial review

Runs `act fanout` to dispatch the user's prompt across every installed AI coding CLI
in parallel, then runs a Claude-driven review gate on the outputs.

Backend: `agent-control-tower` at `/path/to/agent-control-tower/`.
CLI entrypoint: `act fanout <prompt> [flags]`.
Playbook: `/path/to/your-project/docs/guides/MULTIASK_PLAYBOOK.md`.

## When you fire this skill

1. First, decide whether auto-triggering is actually warranted using the strict rules
   in the description. If the question is not clearly in categories (a)-(d), DO NOT
   fire — just answer directly or invoke `/ask` for a single provider.

2. If firing, announce it briefly BEFORE running so the user can interrupt:
   > "This looks security-critical — firing /multiask --adversarial to cross-check.
   > ~1 min and ~1M tokens. Say 'skip' to cancel."
   Then run `act fanout`.

3. Default to `--review adversarial` when auto-triggering. The whole point of
   auto-trigger is high-stakes questions where inferior answers cost you.

## How to invoke

Use the Bash tool to run:

```
act fanout "<user's prompt>" --review adversarial
```

Optional flags:
- `--runtimes claude,codex,gemini,copilot,kiro-cli` — explicit subset
- `--timeout 5` — per-runtime timeout (default 10m)
- `-C <path>` — working directory (default cwd)

The command prints the verdict.md path on exit. Read it with the Read tool and
present it inline to the user. If the command exits non-zero, show stderr and stop.

## Known limitations

- Claude runtime often REJECTs in its own host session due to SessionStart hook noise.
  If you see claude REJECT with "hook noise" reason, that's expected, not a bug.
- Copilot uses the standalone `copilot` CLI with `--allow-all-tools`, not `gh copilot`.
  Requires `gh auth login` once for GitHub auth underneath.
- See the playbook for full troubleshooting and observed timings.

## When NOT to fire

If you are at all unsure, do one of:
- Invoke `/ask <provider>` for a single-provider answer (one-tenth the cost)
- Answer directly from your own reasoning
- Ask the user "do you want me to cross-check with /multiask?"

Never fire `/multiask` twice for the same user turn. If adversarial review rejected
all engines, report that honestly and ask the user how to proceed — don't retry.
