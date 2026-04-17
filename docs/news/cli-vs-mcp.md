---
title: The CLI vs MCP Debate Is Asking the Wrong Question
parent: Multi-Model Orchestration
grand_parent: News & Research
nav_order: 2
---
# The CLI vs MCP Debate Is Asking the Wrong Question

**Source:** Reza Rezvani, [The CLI vs MCP Debate Is Asking the Wrong Question](https://alirezarezvani.medium.com/the-cli-vs-mcp-debate-is-asking-the-wrong-question-a4251e45f7a0) (Medium, 2026-04-05, 12 min read)

## Key takeaways

- **Choose per integration, not per system.** OpenClaw team's production split is **~70% CLI / 30% MCP** — empirical outcome, not philosophy.
- **MCP-only broke at OpenClaw in three weeks.** Six MCP servers loaded ~48,000 tokens of schemas before the user typed a character.
- **Controlled comparison (5 workflows):** MCP-only 67,200 tokens/74% completion vs hybrid 23,400 tokens/96% completion. 2.5× faster.
- **Context is attention, not storage.** 48K of plumbing lobotomises the agent.
- Both camps get things wrong. CLI can't do multi-tenant OAuth; MCP lacks native composability.
- **The real leverage is agent-native tool interface design** — machine-readable output, schema introspection, input validation, dry-run modes.

## The frustration that prompted the piece

> "Every week brings another 'MCP is dead' post. After fifteen months running both in production, here is what the benchmarks will not tell you. [...] The data is solid. The frustration comes from watching an entire community optimize a debate at the wrong layer of abstraction."

## What broke at OpenClaw

Started MCP-first January 2026. Wired up MCP servers for GitHub, Slack, Postgres, and three internal SaaS tools.

> "Production broke that cleanliness within three weeks. [...] Multi-step reasoning tasks that should have completed in a single agent session started requiring splits. An agent tasked with reading a GitHub PR, checking CI status, updating a Jira ticket, and posting a summary to Slack would lose coherence around step three. The quality of its decisions degraded visibly. It would hallucinate parameters. It would call the wrong tool. It would loop."

### The cause

- Six MCP servers = **~48,000 tokens of tool schemas** loaded before the user typed a character
- On 200K context window, **24% consumed by plumbing**
- On 128K context window, **37.5% consumed by plumbing**
- The agent was reasoning with one arm tied behind its back

### The fix — 11-day migration

Moved **execution** tasks (git, files, builds, deploys) to CLI. MCP stayed for **structured reads** (OAuth SaaS, tool discovery where output format mattered).

## The data

Controlled comparison over one week, five workflows, same agents/models.

| Metric | MCP-only | Hybrid (CLI exec + MCP reads) |
|:--|:--|:--|
| Median tokens per workflow | 67,200 | 23,400 |
| Workflow completion rate | 74% | **96%** |
| Multi-step reasoning failures | 31% of runs | **8% of runs** |
| Average completion time | 47 s | **19 s** |

## The ScaleKit data the debate leans on

- 75 head-to-head comparisons; CLI won every metric
- **Simplest GitHub task** ("what language is this repo?"): CLI 1,365 tokens vs MCP **44,026 tokens** — 32× difference
- `mcp2cli` project reports **96-99% token savings** converting MCP schemas to CLI commands

## What benchmarks don't tell you

> "Every benchmark in the CLI-versus-MCP discourse tests the same scenario: a single developer automating their own workflow with a mature CLI tool. GitHub. Docker. Kubernetes. These are the 5 percent of integrations where the comparison even makes sense. They share a trait most enterprise software does not have: forty years of Unix CLI culture baked in."

> "The StackOne analysis put it bluntly. Try building an AI agent for an HR operations team. The agent needs to create a candidate in Greenhouse, check benefits in Workday, update compensation in BambooHR, and log it in Lever. Where is the Greenhouse CLI? There is not one. Workday exposes a SOAP API requiring WS-Security headers and HCM-specific XML namespaces. You could wrap each in a shell script, but now you are managing four auth flows, four pagination strategies, four rate-limiting schemes, and four data models. In bash."

## The per-integration decision framework

Three factors:

1. **Where does the tool run?** Local → CLI. Remote → depends.
2. **How does it authenticate?** Ambient credentials → CLI. Delegated OAuth multi-tenant → MCP.
3. **What does the workflow look like?** Single-tenant dev automation → CLI overwhelmingly. Multi-tenant production acting on behalf of customers → MCP governance.

## OpenClaw's production split

| Task | Transport | Why |
|:--|:--|:--|
| Git (commit, PR, branch) | CLI | Model knows `gh` natively. Zero schema overhead. Near-100% reliability. |
| File system operations | CLI | `find`, `grep`, `sed` — agent composes without instruction. |
| Build and test execution | CLI | `npm test`, `docker build` — deterministic, pipeable, versioned. |
| Slack messaging | MCP | OAuth delegation across team workspaces. |
| SaaS API queries (structured data) | MCP | Typed responses prevent malformed calls. Schema discovery matters. |
| Services without CLIs | MCP | No alternative exists. Shell-wrapper doesn't scale past two. |

> "The 70/30 split is not a principle. It is an empirical outcome. Every integration earned its transport through failure, not theory."

## Two production examples

### CLI wins — code review automation

`git diff main...feature-branch` + `npm test` + `eslint --format json` + post summary. Every step is a shell command the model already knows.

- CLI: **4,200 tokens total**, single session
- MCP: 38,000 tokens, 22% failure rate from context pressure

### MCP wins — cross-platform incident response

PagerDuty alert + Datadog metrics + Jira incident ticket + Slack on-call notification. Four services, four OAuth flows, four data models, each requiring delegated authentication.

- MCP overhead: ~31,000 tokens (real)
- **CLI alternative isn't "use CLI" — it's "build your own protocol layer and call it something other than MCP"**

## What both camps get wrong

### CLI camp — right about

- Token efficiency (documented)
- Unix composability (50 years of hardening)
- Native LLM fluency in shell

### CLI camp — wrong about

- Single-dev security model doesn't scale to multi-tenant production
- Most SaaS services don't have CLIs and never will (benchmarks cherry-pick world-class CLIs)

### MCP camp — right about

- Governance requirements (audit trails, permission scoping, typed schemas, delegated auth) are real compliance

### MCP camp — wrong about

- "Token overhead is the price of admission" dismisses that **48K of plumbing directly degrades agent reasoning quality**
- **Lack of native composability is a genuine architectural gap.** Can't pipe one MCP tool's output into another. Unix solved this decades ago.

## The real leverage — agent-native tool design

> "The debate reveals something about how we think about agent architecture that goes beyond protocol choice. We keep optimizing the transport layer when the real leverage is in tool interface design."

### A well-designed tool (regardless of transport)

- Machine-readable output by default
- Schema introspection at runtime
- Input validation that catches the mistakes agents make (path traversals, double-encoded strings, control characters)
- Dry-run modes for safe exploration

### Hybrid tooling is emerging

- Google's `gws` CLI ships with a built-in MCP server — it is both simultaneously
- `CLI-Anything` and `mcp2cli` bridge from both directions

## Questions that matter (per the author)

- What happens when MCP matures its composability story and the chaining gap closes?
- What happens when every CLI ships `--output json` and schema introspection as standard?
- Are we building for today's context window constraints or tomorrow's million-token windows where schema overhead might not matter?
- What does the abstraction layer above both protocols look like — the one that makes the transport decision invisible to the agent?

## Rezvani's closing

> "The only thing I am confident about is that framing it as a war is wasted energy. Choose per integration. Measure. Adjust. The protocol is plumbing. The architecture is what matters."

## Rezvani's skill library

**220+ Claude Code skills & agent plugins** at `github.com/alirezarezvani/claude-skills` — covers Claude Code, Codex, Gemini CLI, Cursor, and 8 more coding agents.

## Related Playbook pages

- [Multi-Model Orchestration]({{ site.baseurl }}/docs/multi-model-orchestration/) — the full hybrid architecture reference
- [Cost & Observability]({{ site.baseurl }}/docs/cost-and-observability/) — measure the 48K-token context consumption directly
- [Regulated AI]({{ site.baseurl }}/docs/regulated-ai/) — when MCP governance becomes compliance requirement
