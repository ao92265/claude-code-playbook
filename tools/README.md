# Playbook Tools

Local utilities for Claude Code introspection and optimization.

## cc-tools

CLI suite that reads your local Claude Code session logs (`~/.claude/projects/**/*.jsonl`) and surfaces:

- **cost-ledger** — per-session cost, subagent (sidechain) vs main-loop split, tool-call frequency
- **cache-radar** — prompt-cache hit rate, worst-offender sessions, $ saved
- **md-lint** — `CLAUDE.md` / `AGENTS.md` linter: line-cap, duplicates, hedging language, contradictions

No deps. Stdlib only. No network. See [cc-tools/README.md](cc-tools/README.md) for usage.

```bash
cd tools/cc-tools
python3 -m cctools cost-ledger --days 7
python3 -m cctools cache-radar --days 30
python3 -m cctools md-lint ~/.claude/CLAUDE.md
```
