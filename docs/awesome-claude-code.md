# Awesome Claude Code

A curated list of tools, plugins, MCP servers, and resources for Claude Code.

> Know something that should be on this list? [Submit a PR](../CONTRIBUTING.md) or [open an issue](https://github.com/ao92265/claude-code-playbook/issues/new).

---

## Plugins

| Plugin | What It Does |
|:-------|:------------|
| **[OMC (Oh My Claude Code)](https://github.com/nicobailey/oh-my-claudecode)** | Advanced session orchestration: autopilot, parallel agents, persistence loops, smart model routing |
| **[BMAD](https://github.com/bmad-method/BMAD-METHOD)** | Multi-agent roles: Architect, Developer, QA, Security Auditor, Product Manager |
| **[Context7](https://github.com/upstreamapi/context7)** | AI-powered documentation search — fetches up-to-date library docs and code examples |
| **[PR Review Toolkit](https://github.com/anthropics/claude-code-plugins)** | Comprehensive PR review with specialized analysis agents |
| **[Commit Commands](https://github.com/anthropics/claude-code-plugins)** | Streamlined git commit, push, and PR workflows |

## MCP Servers

See [docs/mcp-servers.md](mcp-servers.md) for detailed setup and configuration.

| Server | Purpose | Link |
|:-------|:--------|:-----|
| **Playwright** | Browser automation, screenshots, UI testing | [npm](https://www.npmjs.com/package/@anthropic/mcp-playwright) |
| **Memory** | Persistent knowledge graph across sessions | [npm](https://www.npmjs.com/package/@modelcontextprotocol/server-memory) |
| **Filesystem** | Extended file operations | [npm](https://www.npmjs.com/package/@modelcontextprotocol/server-filesystem) |
| **PostgreSQL** | Database queries and schema inspection | [npm](https://www.npmjs.com/package/@modelcontextprotocol/server-postgres) |
| **SQLite** | Local database operations | [npm](https://www.npmjs.com/package/@modelcontextprotocol/server-sqlite) |
| **Puppeteer** | Web scraping and headless browser | [npm](https://www.npmjs.com/package/@anthropic/mcp-puppeteer) |
| **Brave Search** | Web search from Claude Code sessions | [npm](https://www.npmjs.com/package/@anthropic/mcp-brave-search) |
| **GitHub** | Extended GitHub operations beyond `gh` CLI | [npm](https://www.npmjs.com/package/@modelcontextprotocol/server-github) |

## Community Resources

| Resource | Description |
|:---------|:-----------|
| **[Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)** | Official Anthropic docs for Claude Code |
| **[Claude Code GitHub](https://github.com/anthropics/claude-code)** | Official repo — issues, releases, and discussions |
| **[MCP Specification](https://modelcontextprotocol.io/)** | The Model Context Protocol specification and guides |
| **[MCP Servers Directory](https://github.com/modelcontextprotocol/servers)** | Official directory of MCP servers |
| **[Anthropic Cookbook](https://github.com/anthropics/anthropic-cookbook)** | Recipes and patterns for building with Claude |

## CLAUDE.md Templates

This playbook includes 9 templates. See [templates/](../templates/) for the full list:

- General / TypeScript, React / Next.js, Node.js API, Python, Full-stack monorepo, Go, Rust, React Native / Mobile, DevOps / Infrastructure

## Tips & Tricks

- **`/clear` is your best friend.** When switching tasks, always clear context. One task per session = better results.
- **Paste real errors.** Don't describe the error — paste the stack trace. Claude can parse it faster than you can explain it.
- **Scope-lock your prompts.** "Only modify `src/auth/`" prevents Claude from wandering into unrelated code.
- **Use reverse prompting.** "Ask me 20 questions before starting" produces better specs than writing them yourself.
- **Model routing saves money.** Haiku for searches, Sonnet for code, Opus for architecture. See [model comparison](model-comparison.md).
- **Hooks catch mistakes early.** A 30-second TypeScript check after every edit saves 10-minute build failures later.

---

*This list is maintained by the community. Contributions welcome.*
