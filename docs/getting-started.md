---
title: Getting Started
nav_order: 1
---
# Getting Started

Go from zero to productive with Claude Code in 10 minutes.

---

## Step 0: Create a Claude Account

If you don't have one yet, sign up at [claude.ai](https://claude.ai) and choose a plan. See the [Account Setup guide](account-setup.md) for plan comparisons and recommendations.

---

## Step 1: Install the Playbook (2 minutes)

**Option A — Interactive installer:**

```bash
curl -sL https://raw.githubusercontent.com/ao92265/claude-code-playbook/main/scripts/install.sh | bash
```

**Option B — Manual setup:**

```bash
git clone https://github.com/ao92265/claude-code-playbook.git
cd claude-code-playbook

# Copy a template to your project
cp templates/CLAUDE.md /path/to/your/project/CLAUDE.md

# Install skills globally
cp -r skills/check-env ~/.claude/skills/
cp -r skills/deploy ~/.claude/skills/
cp -r skills/handoff ~/.claude/skills/

# Install hooks
mkdir -p ~/.claude/hooks
cp hooks/ts-check.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/ts-check.sh
```

## Step 2: Customize Your CLAUDE.md (3 minutes)

Open the CLAUDE.md you just copied and edit each section:

1. **Project Basics** — Set your language, framework, and module system
2. **Testing** — Specify your test runner and testing conventions
3. **Verification** — Define what "done" means (which commands to run)
4. **Git & GitHub** — Keep the safety rules as-is

Delete sections that don't apply. Every line should prevent a real problem.

## Step 3: Configure Hooks (2 minutes)

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/ts-check.sh",
            "timeout": 30,
            "statusMessage": "Checking TypeScript types..."
          }
        ]
      }
    ]
  }
}
```

For the complete 7-hook setup, see [config/hooks-example.json](../config/hooks-example.json).

## Step 4: Your First Session (3 minutes)

Start Claude Code and try:

```
> /check-env
```

This validates your environment — ports, Docker, credentials, Node.js. Fix any issues it finds.

Then try a real task:

```
> Fix the failing test in src/auth/login.test.ts.
  The error is: "Expected 200, received 401".
  Only modify files in src/auth/. Don't change tests.
```

Notice the pattern: **specific error + scope constraint + clear goal**.

---

## What to Learn Next

| Goal | Resource |
|:-----|:---------|
| Master the core workflow | [Power User Guide](guide.md) |
| Improve your prompts | [Prompt Patterns](prompt-patterns.md) |
| Avoid common mistakes | [Anti-Patterns](anti-patterns.md) |
| Choose the right skill | [Workflow Decision Tree](workflows.md) |
| Pick the right model | [Model Comparison](model-comparison.md) |
| Set up MCP servers | [MCP Servers Guide](mcp-servers.md) |
| See real examples | [Example Sessions](../examples/) |

---

## Working in Large Codebases

Three small habits make Claude Code dramatically more useful in monorepos and large polyglot repos. None require new tooling.

**1. Start Claude in a subdirectory, not the repo root.**

Claude Code walks up the directory tree automatically to find `CLAUDE.md` and project context. Starting at the root pulls every nested `CLAUDE.md`, every skills folder, and every irrelevant doc into your initial context. Starting inside the area you actually intend to change scopes the context to what is relevant.

```bash
# Bad — root of a 40-package monorepo
cd ~/repos/big-monorepo && claude

# Good — the package you're actually working in
cd ~/repos/big-monorepo/packages/payments && claude
```

**2. Add a `.claudeignore` file at the repo root.**

Same role as `.gitignore`, but for what Claude reads when exploring the codebase. Exclude generated code, build artifacts, vendored dependencies, fixtures, and snapshots. A minimal example:

```
node_modules/
dist/
build/
.next/
coverage/
**/__snapshots__/
**/generated/
vendor/
```

The smaller the scannable surface, the more accurate `Grep`/`Glob` answers will be — and the less likely Claude is to confidently quote a stale generated file.

**3. Prefer LSP over `grep` for symbol navigation.**

If you have the OMC LSP tools (or any MCP server exposing `goto_definition` / `find_references` / `workspace_symbols`), use them for symbol lookups in typed codebases. `grep "handleAuth"` returns every comment, log line, and unrelated function with the same name. `lsp_find_references` returns only the actual call sites — which is what you almost always want.

---

## The 5 Rules That Matter Most

If you remember nothing else from this playbook:

1. **One task per session.** Multi-task sessions degrade quality.
2. **Paste real errors.** Don't describe — paste the stack trace.
3. **Scope-lock your prompts.** "Only modify `src/auth/`" prevents drift.
4. **Verify with real tests.** "Looks correct" ≠ "passes tests".
5. **Start fresh above 80% context.** Use `/handoff` to preserve context for the next session.
