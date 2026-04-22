---
title: Harness
nav_order: 40
parent: Architecture
---
# Harness — What It Is, How To Implement

"Harness" is the word that keeps showing up in AI-coding threads and nobody bothers defining it. It matters because the thing people call "Claude Code" is three layers stacked, and most confusion comes from conflating them.

---

## The Three Layers

| Layer | Example | What it does |
|:------|:--------|:------------|
| Model | `claude-opus-4-7`, `claude-sonnet-4-6` | Generates tokens. Stateless. |
| **Harness** | Claude Code, Cursor, Kiro, Copilot CLI, Agent SDK | Loop around the model: call → run tool → feed result back → repeat. Handles permissions, hooks, context compaction, subagents, sessions. |
| Rules / skills | AGENTS.md, CLAUDE.md, [aidlc-workflows](https://github.com/awslabs/aidlc-workflows), OMC, BMAD | Prompts + workflow files injected *into* the harness to shape behavior. |

**Rules files are not harnesses.** aidlc-workflows, OMC, BMAD — they all ride inside an existing harness (Claude Code, Kiro, Cursor). Same for skills in this playbook.

The harness is the runtime that turns a single `messages.create` API call into an agentic session with file edits, shell commands, and recoverable state.

---

## Why The Distinction Matters

When a teammate says "we need a harness", clarify which of these they actually want:

1. **An agentic IDE/CLI to use day-to-day** → Claude Code, Cursor, Copilot, Kiro. Don't build. Configure.
2. **Programmatic control over the agent loop** → Claude Agent SDK. Build on top.
3. **Workflow rules to shape how the agent works** → AGENTS.md / CLAUDE.md / skills. Write rules, not code.
4. **A custom agent loop from the bare API** → raw `messages.create` + tool dispatch. Only if SDK too opinionated. Usually wrong answer.

90% of the time the ask is (1) or (3). People say "harness" when they mean "rules".

---

## Path 1 — Use The Existing Harness (Default)

Claude Code **is** the harness. It ships with:

- Tool-use loop (Read / Edit / Write / Bash / Task / etc.)
- Permission prompts and allowlists (`.claude/settings.json`)
- Hooks (PreToolUse, PostToolUse, UserPromptSubmit, SessionStart, Stop)
- Subagents via `Agent` / `Task` tool
- Context compaction (`/compact`, `/clear`)
- Session persistence and resume

Configure it with:
- [`CLAUDE.md`](../templates/CLAUDE.md) — project rules
- [`.claude/settings.json`](../config/settings-example.json) — permissions, env, hooks
- [`.claude/hooks/`](../hooks/) — deterministic guardrails
- [`.claude/skills/`](../skills/) — slash-command workflows

**If you are asking "how do I implement a harness", this is the answer. Stop here unless you have a concrete reason to go further.**

---

## Path 2 — Build Custom With Claude Agent SDK

Use when:
- Agent embedded inside another app (not an IDE, not a CLI)
- Headless CI/CD runs where you need programmatic start/stop
- Custom tool whitelist (e.g. only allow SQL + HTTP, no shell)
- Scheduled/triggered agents (cron, webhooks, queue workers)

TypeScript:

```bash
npm install @anthropic-ai/claude-agent-sdk
```

```ts
import { query } from "@anthropic-ai/claude-agent-sdk";

const result = await query({
  prompt: "Audit dependencies and open a PR if any are vulnerable.",
  options: {
    allowedTools: ["Read", "Grep", "Bash"],
    maxTurns: 20,
    permissionMode: "acceptEdits",
  },
});
```

Python:

```bash
pip install claude-agent-sdk
```

```python
from claude_agent_sdk import query, ClaudeAgentOptions

async for msg in query(
    prompt="Audit deps and open a PR if any are vulnerable.",
    options=ClaudeAgentOptions(
        allowed_tools=["Read", "Grep", "Bash"],
        max_turns=20,
        permission_mode="acceptEdits",
    ),
):
    print(msg)
```

SDK gives you the loop, tool dispatch, permission hooks, and MCP client. You wrap it with your trigger, storage, and UX.

---

## Path 3 — Write Rules, Not Code

Most "build us a harness" requests are really "tell the agent how to behave". That's a rules problem, not a runtime problem.

Rules layer options, ordered from lightest to heaviest:

| Layer | Scope | Loaded | When |
|:------|:------|:-------|:-----|
| `CLAUDE.md` / `AGENTS.md` | Project | Every session | Always-on conventions (commit style, verification rules, change philosophy) |
| `.claude/skills/<name>/SKILL.md` | Project or `~/.claude/skills/` global | On invocation (`/<name>` or auto-trigger) | Reusable workflows (deploy checklist, TDD loop) |
| `.claude/hooks/*.sh` | Project or global | Deterministic events | Must-always-happen guardrails (type check, secret scan) |
| Subagent frontmatter (`model:`, `tools:`) | Per agent | When agent invoked | Specialize per-role (reviewer, tester, executor) |

Rule of thumb from this playbook:

> Skills vs hooks: if it must **always** happen, write a hook. If it **usually** should, write a skill.

See [path-scoped-rules.md](path-scoped-rules.md) for directory-scoped `CLAUDE.md` and [plugin-authoring.md](plugin-authoring.md) for packaging rules as a distributable plugin.

---

## Worked Example — aidlc-workflows

[awslabs/aidlc-workflows](https://github.com/awslabs/aidlc-workflows) is the clearest public example of Path 3 done well.

- Ships `core-workflow.md` (the entry rule) + `aidlc-rule-details/` (detail files loaded on demand)
- Supports 7 harnesses out of the box: Kiro, Amazon Q, Cursor, Cline, Claude Code, Copilot, generic `AGENTS.md`
- Uses `.opt-in.md` sidecar files to defer loading full rule bodies until the user consents (saves context)
- Logs every user prompt raw into `aidlc-docs/audit.md` for compliance traceability
- Gates every phase with a 2-option approval ("Request Changes | Continue")

It is not a harness. It is a rules package that rides inside whatever harness you already use. Worth stealing patterns from — see [audit-log-hook.md](audit-log-hook.md) for the audit-log pattern adapted to Claude Code.

---

## Decision Checklist

Before asking anyone to "build a harness", answer:

- [ ] Can Claude Code + CLAUDE.md + skills + hooks do this? → Path 1. Done.
- [ ] Do I need to embed the agent in a non-IDE context (webhook handler, CI job, internal service)? → Path 2, Agent SDK.
- [ ] Am I really just describing a workflow the agent should follow? → Path 3, write rules.
- [ ] Am I trying to reinvent tool-use / permissions / compaction? → Stop. Use the SDK.

If the answer to all of these is no, you probably do not need a harness. You need a clearer prompt and a CLAUDE.md.

---

## FIS Defaults

For Force Information Systems / Harris projects:

- **Day-to-day dev**: Claude Code (this playbook's defaults)
- **CI/CD**: Claude Code headless (`claude --print`) or Agent SDK in GitHub Actions — see [github-actions.md](github-actions.md)
- **Compliance-audited projects**: Claude Code + [audit-log hook](audit-log-hook.md) for raw-prompt logging
- **Multi-IDE teams**: ship rules as `AGENTS.md` (detected by Cursor, Copilot, Kiro, Cline) plus project-local `.claude/skills/`

One harness per project. Pick it. Document it in the project README. Don't mix harnesses in the same working tree — permissions, hook paths, and state files collide.
