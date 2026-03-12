# Claude Code Cheat Sheet

Pin this next to your monitor.

---

## Essential Commands

| Command | What It Does |
|---------|-------------|
| `/clear` | Wipe conversation context — use when switching tasks |
| `/compact` | Compress context to fit more — use at 50% capacity |
| `/rewind` | Undo your last message, keep the session |
| `/context` | Show token usage breakdown (system, tools, conversation) |
| `/mcp` | Show MCP servers + per-server token cost — disable unused ones |
| `/fast` | Toggle fast mode (same model, lower latency) |
| `/help` | List all commands or get details on a specific one |
| `/quit` | End session and exit |

---

## Session Management

| Context Usage | Action |
|--------------|--------|
| < 50% | You're fine. Keep working. |
| 50-80% | Run `/compact` to compress and continue |
| > 80% | Start a fresh session. Context is too polluted. |
| Switching tasks | Run `/clear` before starting the new task |
| Claude "getting dumber" | Context pollution. Start fresh. |

**Golden rule:** One task per session. Multi-task sessions have lower success rates.

---

## CLAUDE.md Setup (5 Steps)

```bash
# 1. Copy the template
cp claude-code-playbook/templates/CLAUDE.md your-project/CLAUDE.md

# 2. Set your language/stack at the top
# 3. Add your coding conventions and patterns
# 4. Add safety rules (no push without permission, always run tests)
# 5. Add lessons learned as you discover them
```

---

## Hook Setup (30 Seconds)

```bash
cp claude-code-playbook/hooks/ts-check.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/ts-check.sh
# Add to ~/.claude/settings.json — see hooks/README.md
```

---

## Skill Installation

```bash
# Global (all projects)
cp -r claude-code-playbook/skills/check-env ~/.claude/skills/

# Project-local (this project only)
cp -r claude-code-playbook/skills/deploy .claude/skills/
```

---

## Prompts That Work

**Bug fix:**
```
This test fails with "Expected 200, received 413" when uploading a PNG > 5MB.
Make the test pass. Don't change the test.
```

**New feature (clear scope):**
```
Only modify files in src/auth/. Do not touch tests or other modules.
Add rate limiting to the login endpoint — max 5 attempts per minute per IP.
```

**New feature (unclear scope):**
```
Ask me 20 clarifying questions about how this feature should work
before you start implementing anything.
```

**Planning:**
```
Plan the approach first. Don't write any code yet.
What files need to change? What are the risks?
```

**Following a pattern:**
```
Look at how UserService is structured. Build OrderService
following the exact same pattern.
```

**Verification:**
```
Run npm test and tsc --noEmit. Show me the output.
Don't say you're done until both pass.
```

**Scope lock:**
```
Fix ONLY this bug. No refactoring. No improvements.
Change the minimum number of lines possible.
```

**Session end:**
```
Write a handoff summary: what was done, what's left,
decisions made, and gotchas. Save to SESSION_NOTES.md.
```

---

## Prompts That Don't Work

| Anti-Pattern | Why It Fails |
|-------------|-------------|
| "Make the code better" | "Better" is undefined. Claude will refactor everything. |
| "Fix the login, add the widget, update docs" | Multi-task = context pollution. One task per session. |
| "The build is broken. Fix it." | No error message = Claude guesses. Paste the actual error. |
| "That's not quite right. Try again." | Iterating pollutes context. Clarify spec, start fresh. |
| "Here's my 800-line file, find the bug" | Extract the relevant 20 lines. Save your context tokens. |
| "Fix everything" | No priority, no scope. Claude chases low-value issues. |
| "Looks good, ship it" | You didn't run tests. The 10% that looks correct but isn't = prod bugs. |
| "Your code must be wrong" | Check your environment first — stale deploy? Wrong Node version? |

---

## Quick Troubleshooting

| Symptom | Fix |
|---------|-----|
| Claude giving generic answers | Context polluted. `/clear` or start fresh. |
| Node.js OOM during build | `NODE_OPTIONS='--max-old-space-size=4096' npm run build` |
| Tables not rendering on GitHub | Check for `\r\r\n` double carriage returns in your markdown |
| Hooks not triggering | Check `matcher` in settings.json matches the tool name exactly |
| Skills not appearing | Verify SKILL.md has valid YAML frontmatter with `---` delimiters |
| Parallel agents hitting rate limits | Cap at 3-4 agents max |
| Git credential failures in sub-agents | Run `gh auth status` before spawning agents |
| Claude modifying wrong files | Add explicit constraints: "Only modify src/auth/" |
| ESM/CJS import errors | State your module system in CLAUDE.md |
| Claude over-engineering | Add to CLAUDE.md: "Make the smallest change that works" |

---

## Plugin Quick Install

```bash
claude /plugin install Context7     # AI-powered documentation search
claude /plugin install BMAD         # Multi-agent orchestration (Architect, Dev, QA, Security, PM)
claude /plugin install OMC          # Advanced session management (autopilot, ralph, ultrawork)
```

---

## Model Routing

| Model | Cost | Use For |
|-------|------|---------|
| **Haiku** | Lowest | File searches, formatting, boilerplate, simple lookups |
| **Sonnet** | Medium | Standard implementation, code editing, bug fixes, testing |
| **Opus** | Highest | Architecture decisions, complex debugging, difficult reasoning |

When spawning sub-agents:
```
model: "haiku"   — simple tasks
model: "sonnet"  — implementation work
model: "opus"    — complex decisions only
```

---

## Key Numbers

| Threshold | Value |
|-----------|-------|
| Max parallel agents | 3-4 |
| Context compact threshold | 50% |
| Context restart threshold | 80% |
| Build memory flag | `--max-old-space-size=4096` |
| Build memory escalation | `--max-old-space-size=8192` |
| CLAUDE.md shared file max | 30 lines |
