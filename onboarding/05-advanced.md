# Step 5: Advanced Features (20 minutes)

These are power-user features. You don't need them on day one, but they'll multiply your productivity as you get comfortable.

## Model Routing

Claude Code has three model tiers. The default (Sonnet) handles most work, but you can optimize:

| Model | When to Use | How |
|:------|:-----------|:----|
| **Haiku** | Quick lookups, formatting | `/fast` toggle |
| **Sonnet** | Standard coding (default) | Automatic |
| **Opus** | Complex architecture, hard bugs | Use when Sonnet struggles |

**Rule of thumb:** If Sonnet can't solve it in 2 attempts, try with Opus reasoning.

See the full [model comparison guide](../docs/model-comparison.md).

## Context Management

Your context window is finite. Manage it:

| Context % | Action |
|:---------:|:-------|
| < 50% | Keep working normally |
| 50-80% | Run `/compact` to compress |
| > 80% | Start a fresh session (use `/handoff` first) |

Check usage anytime with `/context`.

**Why this matters:** Claude gets worse as context fills up. Old failed approaches, debug output, and rejected ideas compete for attention. Fresh sessions produce better code.

## Multi-Agent Work

For large features (5+ files), Claude can spawn parallel agents:

```
Build a notifications system:
- Database schema and migration
- API endpoints (GET list, PATCH mark-read)
- React component with dropdown

These are independent — parallelize where possible. Cap at 3 agents.
```

**Safety rules:**
- Cap at 3-4 agents (more = rate limit issues)
- Each agent works in its own worktree (no conflicts)
- Always run the full test suite after merging agent results
- Specify `model: "sonnet"` for implementation agents

See the [multi-agent example](../examples/multi-agent-session.md) for a full walkthrough.

## Hooks In-Depth

Hooks are automatic checks. You've been using them — here's what's happening:

| Hook | When It Runs | What It Catches |
|:-----|:------------|:----------------|
| `ts-check.sh` | After every TS file edit | Type errors |
| `lint-check.sh` | After every JS/TS edit | ESLint violations |
| `format-check.sh` | After every edit | Formatting issues |
| `env-guard.sh` | Before git commands | Secrets in commits |
| `pre-commit-guard.sh` | Before git commit | console.log, debugger |
| `commit-message-check.sh` | Before git commit | Non-conventional commit messages |
| `test-on-save.sh` | After edits (async) | Related test failures |
| `build-check.sh` | After TS edits | Build failures, OOM |
| `session-start-check.sh` | Session start | Environment issues |

You can disable individual hooks by removing them from `~/.claude/settings.json`.

## Reverse Prompting

Instead of writing detailed specs, let Claude ask you:

```
I need to add user authentication to this app.
Ask me 20 clarifying questions before you start.
```

Claude's questions reveal edge cases you haven't considered. Answer them, and you get a better spec than you'd write yourself.

## Custom Skills

You can create skills specific to your team's workflows:

1. Create `~/.claude/skills/my-skill/SKILL.md`
2. Add YAML frontmatter with name, description, metadata
3. Write the step-by-step workflow in markdown
4. Use it with `/my-skill`

See [CONTRIBUTING.md](../CONTRIBUTING.md) for the format.

## Further Reading

| Topic | Resource |
|:------|:---------|
| All 27 skills | [Workflow decision tree](../docs/workflows.md) |
| Common mistakes | [20 anti-patterns](../docs/anti-patterns.md) |
| Model selection | [Model comparison](../docs/model-comparison.md) |
| MCP servers | [MCP guide](../docs/mcp-servers.md) |
| Prompt patterns | [20 prompt patterns](../docs/prompt-patterns.md) |
| Full reference | [Power user guide (667 lines)](../docs/guide.md) |

---

**Next: [checklist.md](checklist.md)** — Verify you're ready
