# MCP Servers Guide

Model Context Protocol (MCP) servers extend Claude Code's capabilities beyond code editing — giving it access to browsers, databases, documentation, and external services.

---

## What Are MCP Servers?

MCP servers are local processes that expose tools to Claude Code over a standardized protocol. The MCP ecosystem has grown to **300+ servers** as of early 2026, covering databases, APIs, monitoring, project management, and more. When you enable an MCP server, its tools appear alongside Claude's built-in tools. Claude can then call them during a session to perform actions like taking screenshots, querying databases, or fetching documentation.

**The trade-off:** Each MCP server adds tools to your context window. More tools = fewer tokens available for your actual work. Only enable what you actively use.

> **New in 2026:** MCP Tool Search (lazy loading) is now enabled by default. Claude only loads tool definitions when it needs them, reducing context usage by up to 95%. This significantly reduces the "context tax" of having many MCP servers enabled.

---

## Recommended MCP Servers

| Server | Purpose | Context Cost | When to Enable |
|--------|---------|-------------|----------------|
| **Playwright / Browser** | Screenshots, UI testing, form filling, navigation | High (~15 tools) | Frontend development, visual verification, E2E testing |
| **Context7** | Fetch up-to-date library documentation and code examples | Low (~2 tools) | When using unfamiliar libraries or APIs |
| **Memory** | Persistent knowledge graph across sessions | Medium (~8 tools) | Long-running projects where cross-session memory matters |
| **Filesystem** | Extended file operations (search, move, batch ops) | Medium (~8 tools) | Large codebases where built-in tools feel limiting |
| **Puppeteer** | Web scraping, headless browser automation | High (~12 tools) | Data extraction, automated testing, screenshot workflows |
| **Sentry** | Error monitoring, issue tracking, release management | Medium (~6 tools) | Production debugging, incident response |
| **Linear** | Issue tracking, project management | Medium (~5 tools) | Sprint planning, issue triage sessions |
| **PostgreSQL / SQLite** | Database queries, schema inspection, migrations | Medium (~6 tools) | Backend development with database work |
| **GitHub** | Extended GitHub operations beyond `gh` CLI | Medium (~8 tools) | PR management, CI/CD workflows, issue automation |
| **Slack** | Read/send messages, channel management | Medium (~6 tools) | Incident response, team communication automation |
| **Chrome DevTools** | Browser automation, screenshots, performance audits, Lighthouse | High (~20 tools) | Frontend development, performance optimization, visual testing |
| **Jira** | Issue tracking, sprint management, backlog grooming | Medium (~8 tools) | Enterprise teams using Atlassian stack |
| **ServiceNow** | Incident management, change requests, CMDB | Medium (~6 tools) | Enterprise IT operations, incident response |
| **Confluence** | Documentation search, page creation, knowledge base | Medium (~5 tools) | Teams needing access to internal documentation during coding |
| **Grafana** | Dashboard queries, alert management, metric exploration | Medium (~5 tools) | Performance debugging, observability-driven development |

---

## Configuration

Add MCP servers to `~/.claude/settings.json` (global) or `.claude/settings.json` (project-local):

```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstreamapi/context7-mcp@latest"]
    },
    "playwright": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-playwright"]
    },
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"],
      "env": {
        "MEMORY_FILE": "~/.claude/memory.json"
      }
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "DATABASE_URL": "postgresql://user:pass@localhost:5432/mydb"
      }
    }
  }
}
```

---

## Context Token Impact

Every MCP server consumes context tokens by registering its tools at session start. Here's what that means in practice:

| Tools Registered | Approximate Token Cost | Impact |
|-----------------|----------------------|--------|
| 1-3 tools | ~200-500 tokens | Negligible |
| 5-10 tools | ~1,000-2,000 tokens | Minor — barely noticeable |
| 10-20 tools | ~2,000-5,000 tokens | Moderate — consider disabling if unused |
| 20+ tools | ~5,000+ tokens | Significant — only enable if actively using |

**Rule of thumb:** If you haven't used an MCP server's tools in the last 3 sessions, disable it.

### Checking Your Token Usage

Run `/mcp` in a Claude Code session to see:
- Which MCP servers are connected
- How many tools each provides
- Per-server token cost estimate

---

## When to Disable

Disable MCP servers when:

- **Context is tight** — You're working on a complex task and need every token for reasoning
- **Servers are unused** — You enabled it "just in case" but haven't used it in days
- **Startup is slow** — MCP servers that fail to connect add delay to session start
- **You're using sub-agents** — Each sub-agent inherits MCP servers, multiplying token cost

---

## Security Review for Third-Party MCPs

With 300+ MCP servers available, not all are equally trustworthy. Review checklist before enabling a third-party server:

### Before Installing

| Check | What to Look For |
|:------|:----------------|
| **Source** | Is the package from a known publisher? Check npm/GitHub for maintainer reputation. |
| **Permissions** | What does the server access? File system, network, databases? |
| **Network** | Does it phone home or send data to external services? |
| **Updates** | Is the package actively maintained? Last commit < 6 months? |
| **Dependencies** | Run `npm audit` on the package before enabling. |

### Risk Levels

| Risk Level | Examples | Policy |
|:-----------|:--------|:-------|
| **Low** | Context7 (docs lookup), Memory (local file) | Enable freely |
| **Medium** | GitHub, Linear, Slack (authenticated API calls) | Verify OAuth scopes, review what data is shared |
| **High** | Database servers, filesystem servers | Project-local only, verify connection strings, restrict to dev databases |
| **Custom/internal** | Your own MCP servers | Follow your org's code review process |

### Enterprise Recommendation

Use managed policies (Enterprise plan) to maintain an approved MCP server allowlist. Block unapproved servers to prevent data leakage through unvetted third-party tools.

---

## Troubleshooting

### Server not connecting

```
MCP server "foo" failed to connect
```

1. Test the command manually: `npx -y @package/server-foo`
2. Check if the package exists and version is correct
3. Verify network access (some servers need to download on first run)
4. Check for port conflicts if the server binds to a local port

### Timeout on startup

```
MCP server "foo" timed out
```

- Increase timeout in settings: `"timeout": 30` (default is usually 10s)
- First run of `npx` packages downloads them — retry after initial install

### Permission errors

```
MCP server "foo" error: EACCES
```

- Check file permissions on the server command
- For database servers, verify connection credentials
- For filesystem servers, verify the allowed directories

### Tools not appearing

- Run `/mcp` to check connection status
- Restart the session — MCP tools are loaded at session start
- Verify the server name in settings matches exactly (case-sensitive)

---

## Best Practices

1. **Start minimal** — Enable only Context7 and one other server you'll actually use
2. **Project-local over global** — Put database servers in `.claude/settings.json`, not global
3. **Don't duplicate built-in tools** — Claude already has Bash, Read, Write, Grep, Glob
4. **Disable in CI** — MCP servers add startup time and potential flakiness
5. **Audit periodically** — Review `/mcp` output monthly, disable what you're not using
6. **Review third-party servers** — Check the security review checklist above before enabling any MCP server you didn't write
