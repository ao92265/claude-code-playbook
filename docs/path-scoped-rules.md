# Path-Scoped Rules: Keeping Claude Focused on What Matters

A monolithic `CLAUDE.md` that covers every project convention — TypeScript, React, testing, databases, CI/CD — loads into every session regardless of what you're actually working on. The result is **priority saturation**: all instructions compete for attention equally, so the most critical ones get diluted by the least relevant ones.

Path-scoped rules solve this. Rules only activate when Claude touches files that match a glob pattern. Fixing a React component loads only your React rules. Writing a migration loads only your database rules. The context window stays focused on instructions that are actually relevant.

---

## What Are Path-Scoped Rules?

Claude Code supports a `.claude/rules/` directory where each Markdown file is a self-contained rule set with a YAML frontmatter header. The `globs` field controls when the rule file activates.

When Claude opens or edits a file, it checks the filename against all rule globs. Only matching rule files are loaded into context. Non-matching rules are never read.

**Benefits:**
- Context window contains only relevant instructions
- Different teams can own different rule files
- Rules are version-controlled alongside the code they govern
- No single "kitchen sink" file that grows unbounded

---

## Setup

Create the rules directory in your project:

```bash
mkdir -p .claude/rules
```

Your project structure will look like:

```
.claude/
  rules/
    typescript.md
    react.md
    testing.md
    database.md
CLAUDE.md          # project-wide rules (keep short)
```

`CLAUDE.md` should now contain only truly universal rules: commit format, branch naming, team contacts, tools to avoid. Move everything else into scoped rule files.

---

## Rule File Format

Each rule file is a Markdown document with YAML frontmatter:

```markdown
---
description: <short description shown in Claude UI>
globs: ["<glob-pattern>", "<glob-pattern>"]
---

# Rule Title

- Rule 1
- Rule 2
```

**Frontmatter fields:**

| Field | Required | Purpose |
|-------|----------|---------|
| `description` | Recommended | Shown in Claude Code UI; helps you identify the rule |
| `globs` | Required | Array of glob patterns that trigger this rule |

**Glob pattern tips:**
- `**/*.ts` — all TypeScript files anywhere in the tree
- `src/components/**` — everything under `src/components/`
- `**/*.test.ts` — test files specifically
- `db/migrations/**` — migration files only
- `["**/*.ts", "**/*.tsx"]` — multiple patterns in one rule

---

## Example Rule Files

### TypeScript Rules

```markdown
---
description: TypeScript conventions
globs: ["**/*.ts", "**/*.tsx"]
---

# TypeScript Rules

- Run `tsc --noEmit` after every multi-file change — do not skip this
- No `any` types. Use `unknown` when the type is genuinely unknown
- No non-null assertions (`!`) — use explicit null checks instead
- Prefer interfaces over type aliases for object shapes
- Export types explicitly — do not rely on inferred types in public APIs
```

### React Component Rules

```markdown
---
description: React component conventions
globs: ["src/components/**/*.tsx", "src/pages/**/*.tsx"]
---

# React Rules

- Functional components only — no class components
- Co-locate component styles in a `.module.css` file with the same name
- Props interfaces named `<ComponentName>Props`
- No inline styles — use CSS modules or Tailwind classes
- Extract hooks to `src/hooks/` when logic exceeds 20 lines
- Every user-facing string must go through the `t()` i18n function
```

### Testing Rules

```markdown
---
description: Test file conventions
globs: ["**/*.test.ts", "**/*.test.tsx", "**/*.spec.ts"]
---

# Testing Rules

- Run `npm test -- --testPathPattern=<file>` to test a single file
- Do not mock the module under test — mock its dependencies
- Prefer `findBy*` over `getBy*` for async assertions in React Testing Library
- Each test file covers one module — no cross-file test suites
- Arrange/Act/Assert structure, one blank line between sections
- Never use `it.only` or `describe.only` in committed code
```

### Database / Migration Rules

```markdown
---
description: Database and migration conventions
globs: ["db/migrations/**", "src/db/**", "**/*.sql"]
---

# Database Rules

- All migrations must be reversible — include a `down` migration
- Never DROP COLUMN directly — rename to `deprecated_<name>` first, drop in next release
- Index every foreign key column
- Migration filenames: `YYYYMMDDHHMMSS_<description>.ts`
- Do not run raw SQL in application code — use the query builder
- Test migrations against a local Postgres instance before committing
```

---

## When to Use Rules vs CLAUDE.md

| Content | Where it goes |
|---------|--------------|
| Commit format, branch naming | `CLAUDE.md` |
| "Never push without permission" | `CLAUDE.md` |
| TypeScript-specific compiler requirements | `.claude/rules/typescript.md` |
| React component patterns | `.claude/rules/react.md` |
| Test naming and structure | `.claude/rules/testing.md` |
| DB migration safety rules | `.claude/rules/database.md` |
| Environment setup / port conflicts | `CLAUDE.md` |

**Keep CLAUDE.md under 30 lines.** If it's growing, move content into scoped rules.

---

## Path-Scoped Rules vs Auto-Memory

Rules are static — you write them, they don't change unless you edit the file. Auto-memory is dynamic — Claude writes learnings from sessions into a memory file.

Use rules for **conventions that are always true** (style guides, safety constraints, architectural decisions). Use auto-memory for **things Claude discovered** (this project uses a non-standard config path, this API has a known quirk).

They're complementary. Most projects need both.

---

## Migration Guide: From Monolithic CLAUDE.md

If you have a long, unwieldy `CLAUDE.md`, migrate it in three steps.

### Step 1: Audit your CLAUDE.md

Group your existing rules by category:

```bash
# Copy your CLAUDE.md contents and sort into buckets:
# - TypeScript-specific
# - React/component-specific
# - Test-specific
# - DB/migration-specific
# - Universal (commit format, environment, security)
```

### Step 2: Create scoped rule files

For each category with 3+ rules, create a rule file:

```bash
touch .claude/rules/typescript.md
touch .claude/rules/react.md
touch .claude/rules/testing.md
```

Copy the relevant rules from `CLAUDE.md` into each file, adding the frontmatter header.

### Step 3: Prune CLAUDE.md

Remove the content you moved to rule files. What remains in `CLAUDE.md` should be the truly universal instructions — things that apply no matter which file Claude is editing.

**Before migration:**
```
CLAUDE.md — 85 lines, covering TypeScript, React, testing, DB, git, env
```

**After migration:**
```
CLAUDE.md — 18 lines (universal rules only)
.claude/rules/typescript.md — 12 lines
.claude/rules/react.md — 10 lines
.claude/rules/testing.md — 8 lines
.claude/rules/database.md — 9 lines
```

The total instruction count is similar — but now only the relevant subset loads per session.

---

## Quick Reference

```bash
# Create rules directory
mkdir -p .claude/rules

# Minimum viable rule file
cat > .claude/rules/typescript.md << 'EOF'
---
description: TypeScript rules
globs: ["**/*.ts", "**/*.tsx"]
---

# TypeScript Rules
- Run tsc --noEmit after changes
- No `any` types
EOF
```
