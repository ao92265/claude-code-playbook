---
title: SDK vs CLI
parent: Resources
nav_order: 37
---
# SDK vs CLI

Two ways to run Claude Code: the interactive `claude` binary and the Agent SDK. They share a model but the surrounding scaffolding differs sharply. Choosing the wrong one produces "works on my laptop, fails in CI" surprises.

## Quick Pick

| You want to... | Use |
|----------------|-----|
| Pair-program in a terminal | CLI |
| Run review/test/refactor in CI | CLI in headless mode (`claude -p "..."`) |
| Embed Claude into your own product | Agent SDK |
| Run thousands of evals in parallel | Agent SDK |
| Replicate CLI behaviour from Python/TS code | SDK + `system_prompt_preset="claude_code"` + `settingSources=["project"]` |

## What the CLI Loads Automatically

When you run `claude` in a project, it stitches together:

1. **Base system prompt** (~269 tokens) — identity, capability claims, tool-use conventions
2. **Conditional fragments** (110+) — only loaded if relevant: skills, hooks output, retros, MCP catalogue, plan-mode block, etc.
3. **CLAUDE.md hierarchy** — global (`~/.claude/CLAUDE.md`) → parent dirs → project root → working dir
4. **Settings** — `~/.claude/settings.json` and `.claude/settings.json` (merged, project wins)
5. **Hooks** — registered in settings, fire automatically
6. **Skills** — from `.claude/skills/` and `~/.claude/skills/`
7. **Plugins** — from configured marketplaces
8. **Memory** — `~/.claude/projects/<project>/memory/MEMORY.md` and per-agent memory files

## What the SDK Loads by Default

Almost none of the above. A bare `Agent()` call gets you the API and your `tools=[...]`. Everything else is opt-in:

```python
from claude_agent_sdk import Agent

agent = Agent(
    system_prompt_preset="claude_code",     # 1. base prompt + fragments
    settingSources=["project"],             # 2. CLAUDE.md + settings.json
    # skills, hooks, plugins still need explicit registration
)
```

The `claude_code` preset is the closest the SDK gets to "act like the CLI". It does not magically pick up project hooks — those still need wiring through the SDK's hook API.

## Headless CLI vs SDK

Both can run non-interactively:

```bash
claude -p "review the diff against main and report risk" \
  --output-format json --max-budget-usd 0.50
```

```python
result = await agent.run("review the diff against main and report risk")
```

Differences:
- **CLI headless** still loads CLAUDE.md, hooks, skills — the full project context.
- **SDK** only loads what you wired up. Cleaner, faster, but you own the context.
- **CLI headless** is better for "do CI tasks the same way the team does locally"; **SDK** is better for "build a product".

## Common Trap: SDK Without `settingSources`

If your SDK app does not call `settingSources=["project"]`, it will not read CLAUDE.md. You will spend an hour wondering why "the rules are clearly there" but the model ignores them. They are not loaded.

## Determinism

Neither environment is deterministic. There is no `seed`. `temperature=0` reduces but does not eliminate variation. CI assertions on model output should snapshot, not regex-match.

## When to Build on Each

**Stick with CLI when:**
- The workflow is developer-facing and project-local
- You can express the task as a slash command + skills + hooks
- You want every team member's environment to look the same

**Reach for the SDK when:**
- You are shipping Claude inside another product
- You need fine-grained control over context, caching, retries
- You need parallelism beyond a few subagents
- You want to charge for it (CLI is a developer tool, not an embedding fabric)

## See Also

- [Advanced Tool Use](advanced-tool-use.md)
- [GitHub Actions](github-actions.md) — CLI in CI
- [Multi-Model Orchestration](multi-model-orchestration.md)
