---
title: Advanced Tool Use
parent: Resources
nav_order: 36
---
# Advanced Tool Use

Patterns for the Anthropic API and Agent SDK that go beyond standard `tools=[...]`. Mostly relevant when building agents on top of Claude — not all of these surface in the Claude Code CLI itself.

## Programmatic Tool Calling

`allowed_callers: ["code_execution_20250825"]` lets Claude execute tool calls inside the code-execution sandbox instead of round-tripping each one through your application. Reported token reduction: **~37%** on tool-heavy chains, because intermediate results never leave the sandbox.

```python
client.messages.create(
    model="claude-opus-4-7",
    tools=[
        {
            "name": "search_db",
            "description": "...",
            "input_schema": {...},
            "allowed_callers": ["code_execution_20250825"],
        },
    ],
    betas=["code-execution-2025-08-25"],
    ...
)
```

When to use:
- Long tool chains where each call's output feeds the next (ETL, multi-step queries)
- Tool calls that produce large intermediate JSON the model would otherwise re-summarise

When to skip:
- Tool calls with side effects you need to observe (sending emails, writing to prod DBs) — those need to round-trip
- One-shot tool calls

## Tool `input_examples`

Adding 2–4 concrete example calls in the tool definition raises tool-use accuracy from ~72% to ~90% on ambiguous schemas (Anthropic-reported). Cheaper than fine-tuning, no infra change.

```json
{
  "name": "create_ticket",
  "description": "...",
  "input_schema": {...},
  "input_examples": [
    {"title": "Login fails on Safari", "priority": "high", "labels": ["bug", "auth"]},
    {"title": "Q3 onboarding doc", "priority": "low", "labels": ["docs"]}
  ]
}
```

Rule of thumb: include an example for every distinct shape the schema permits, especially around enums and optional fields.

## MCPSearch Auto-Mode

`ENABLE_TOOL_SEARCH=auto:N` makes the model search the available MCP tool catalogue **only when it has more than N tools loaded**. Below the threshold, all tools are injected into the prompt directly (cheaper, lower latency); above it, the model performs a search step first.

Reasonable defaults:
- `auto:30` — balanced
- `auto:10` — aggressive, save context aggressively
- unset (always inject) — fast, but burns context with 50+ tools

## SDK vs CLI System Prompts

The Claude Code binary ships a base system prompt of ~269 tokens plus 110+ conditionally-loaded fragments (skills, hooks, retros, MCP catalogues). The Agent SDK does not load any of that by default. To get CLAUDE.md, settings, and project skills inside an SDK app:

```python
from claude_agent_sdk import Agent

agent = Agent(
    system_prompt_preset="claude_code",     # apply the CLI's base prompt
    settingSources=["project"],             # read .claude/settings.json + CLAUDE.md
)
```

Without `settingSources`, the SDK is essentially a raw API client. With it, headless pipelines behave the same as an interactive `claude` session in the same repo. See [SDK vs CLI](sdk-vs-cli.md).

## Determinism — None

Claude has no `seed` parameter. `temperature: 0` reduces variance but does not eliminate it. For test suites that need byte-identical output, snapshot the model response on first run and assert against the snapshot — never assert on raw model output across runs.

## Claude Code CLI Relevance

| Pattern | CLI? | API/SDK? |
|---------|------|----------|
| Programmatic Tool Calling | No | Yes |
| `input_examples` | Indirect (via plugin tool defs) | Yes |
| `MCPSearch` auto-mode | Yes (env var) | Yes |
| `system_prompt_preset` | N/A | Yes |
| Token caching | Yes (automatic) | Yes (manual `cache_control`) |

The CLI gives you most of this transparently. If you're writing a custom agent, the SDK + the patterns above will close most of the gap.

## See Also

- [SDK vs CLI](sdk-vs-cli.md)
- [Multi-Model Orchestration](multi-model-orchestration.md)
- [MCP Servers](mcp-servers.md)
