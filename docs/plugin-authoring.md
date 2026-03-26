# Plugin Authoring Guide

How to bundle skills, hooks, and MCP servers into distributable Claude Code plugins.

---

## What Is a Plugin?

A plugin is a packaged bundle of Claude Code extensions — skills, hooks, MCP server configurations, and/or CLAUDE.md rules — that can be installed as a single unit. Plugins are namespaced to avoid conflicts when multiple plugins are installed.

**A plugin can contain any combination of:**
- Skills (custom slash commands)
- Hooks (automatic event-driven scripts)
- MCP server configurations
- CLAUDE.md rule fragments
- Templates and examples

---

## Plugin Structure

```
my-plugin/
├── plugin.json           # Plugin manifest (required)
├── skills/               # Custom slash commands
│   ├── my-skill/
│   │   └── SKILL.md
│   └── another-skill/
│       └── SKILL.md
├── hooks/                # Event-driven scripts
│   ├── my-hook.sh
│   └── another-hook.sh
├── mcp/                  # MCP server configurations
│   └── servers.json
├── rules/                # CLAUDE.md rule fragments
│   └── my-rules.md
├── README.md             # Documentation
└── LICENSE
```

---

## Plugin Manifest (plugin.json)

The manifest defines what the plugin contains and how it's installed:

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "A brief description of what this plugin does",
  "author": "Your Name or Organisation",
  "license": "MIT",
  "namespace": "my-plugin",
  "components": {
    "skills": [
      "skills/my-skill",
      "skills/another-skill"
    ],
    "hooks": [
      {
        "file": "hooks/my-hook.sh",
        "event": "PostToolUse",
        "pattern": "*.ts"
      }
    ],
    "mcpServers": {
      "my-server": {
        "command": "npx",
        "args": ["-y", "@my-org/mcp-server"]
      }
    },
    "rules": [
      "rules/my-rules.md"
    ]
  },
  "dependencies": {
    "node": ">=18.0.0"
  },
  "repository": "https://github.com/my-org/my-plugin"
}
```

### Key Fields

| Field | Required | Description |
|:------|:--------:|:-----------|
| `name` | Yes | Package name (lowercase, hyphens only) |
| `version` | Yes | Semver version |
| `namespace` | Yes | Prefix for all skills to avoid conflicts (e.g., `my-plugin:skill-name`) |
| `components` | Yes | What the plugin provides |
| `dependencies` | No | System requirements |

---

## Writing Skills for Plugins

Plugin skills work the same as standalone skills, but are namespaced:

```markdown
---
name: my-plugin:deploy
description: Deploy using my-plugin's workflow
metadata:
  user-invocable: true
  slash-command: deploy
---

# Deploy Workflow

Steps for deployment...
```

When installed, users invoke it as `/my-plugin:deploy` — the namespace prevents collisions with other plugins that might also have a `deploy` skill.

### Skill Best Practices for Plugins

1. **Always namespace** — Use your plugin name as prefix
2. **Be self-contained** — Don't assume other plugins are installed
3. **Document dependencies** — If your skill needs a tool (e.g., Docker), say so in the description
4. **Use relative paths** — Reference other files in the plugin with relative paths

---

## Writing Hooks for Plugins

Plugin hooks are standard shell scripts with metadata in the manifest:

```bash
#!/bin/bash
# my-hook.sh — Validate API contracts after edits

FILE="$1"

# Only run on API route files
if [[ ! "$FILE" =~ src/api/ ]]; then
  exit 0
fi

# Run contract validation
npx api-contract-validator "$FILE"
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo "API contract violation detected in $FILE"
  exit 1  # Block the edit
fi

exit 0
```

### Hook Events

| Event | Fires When | Common Uses |
|:------|:----------|:-----------|
| `PreToolUse` | Before a tool executes | Block dangerous operations, validate inputs |
| `PostToolUse` | After a tool executes | Run linters, type checkers, tests |
| `SessionStart` | Session begins | Environment validation, context loading |
| `PromptSubmit` | User sends a prompt | Input filtering, routing |
| `TaskCompleted` | Agent team task finishes | Quality gates, notifications |

---

## Including MCP Servers

If your plugin provides an MCP server, include the configuration:

```json
{
  "mcpServers": {
    "my-plugin-server": {
      "command": "npx",
      "args": ["-y", "@my-org/mcp-server@latest"],
      "env": {
        "CONFIG_PATH": "${PLUGIN_DIR}/config.json"
      }
    }
  }
}
```

The installer merges this into the user's `settings.json` under the plugin namespace.

---

## CLAUDE.md Rule Fragments

Plugins can provide rules that get appended to the project's CLAUDE.md context:

```markdown
<!-- rules/my-rules.md -->
## My Plugin Rules

When using my-plugin skills:
- Always validate input before processing
- Log all operations to the audit trail
- Never modify files outside the project root
```

These are loaded automatically when the plugin is active.

---

## Distribution

### npm (Recommended)

Publish to npm for easy installation:

```bash
# In your plugin directory
npm init  # if no package.json exists
npm publish
```

Users install with:
```bash
npx skills install my-plugin
# or
claude /install my-plugin
```

### GitHub

Distribute via GitHub repository:

```bash
npx skills install github:my-org/my-plugin
```

### Local/Private

For internal enterprise plugins, point to a local directory or private registry:

```bash
npx skills install ./path/to/my-plugin
# or
npx skills install --registry https://npm.internal.company.com my-plugin
```

---

## Testing Your Plugin

### Manual Testing

```bash
# Install locally for testing
npx skills install ./my-plugin

# Verify skills appear
claude /my-plugin:deploy --help

# Test hooks fire correctly
claude  # start a session, trigger the hook event
```

### Automated Testing

Create a test script that validates:

```bash
#!/bin/bash
# test-plugin.sh

echo "Testing plugin installation..."
npx skills install ./my-plugin || exit 1

echo "Testing skill availability..."
grep -r "my-plugin:deploy" ~/.claude/skills/ || exit 1

echo "Testing hook execution..."
bash hooks/my-hook.sh test-file.ts
[ $? -eq 0 ] || exit 1

echo "All tests passed."
```

---

## Example: Full Plugin

A complete example — a "code-quality" plugin with a review skill, lint hook, and SonarQube MCP server:

### plugin.json

```json
{
  "name": "code-quality",
  "version": "1.0.0",
  "description": "Automated code quality checks: review skill, lint hook, SonarQube integration",
  "namespace": "code-quality",
  "components": {
    "skills": ["skills/review"],
    "hooks": [
      {
        "file": "hooks/lint-on-save.sh",
        "event": "PostToolUse",
        "pattern": "*.{ts,tsx,js,jsx}"
      }
    ],
    "mcpServers": {
      "sonarqube": {
        "command": "npx",
        "args": ["-y", "@mcp/sonarqube-server"],
        "env": {
          "SONAR_URL": "${SONAR_URL}",
          "SONAR_TOKEN": "${SONAR_TOKEN}"
        }
      }
    },
    "rules": ["rules/quality-rules.md"]
  }
}
```

### skills/review/SKILL.md

```markdown
---
name: code-quality:review
description: Run a comprehensive code quality review
metadata:
  user-invocable: true
  slash-command: quality-review
---

# Code Quality Review

1. Run ESLint with --fix on changed files
2. Check for TypeScript strict mode violations
3. Query SonarQube for existing issues on touched files
4. Produce a summary with severity ratings
```

---

## Enterprise Plugin Management

For organisations distributing plugins internally:

| Concern | Solution |
|:--------|:---------|
| **Version control** | Use semver; pin versions in team settings |
| **Security review** | Review plugin code before adding to approved list |
| **Distribution** | Private npm registry or internal GitHub org |
| **Updates** | `npx skills update` checks for new versions |
| **Conflicts** | Namespacing prevents skill/hook collisions |
| **Rollback** | `npx skills uninstall my-plugin` removes cleanly |

### Managed Policy Integration

Enterprise admins can restrict which plugins are allowed:

```json
{
  "managed_policies": {
    "allowed_plugins": ["code-quality", "deploy-pipeline", "security-scan"],
    "blocked_plugins": ["*"]
  }
}
```

This ensures only approved plugins are installed across the organisation.
