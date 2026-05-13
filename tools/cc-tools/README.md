# cc-tools

Claude Code self-improvement CLI suite. No deps. Stdlib only.

## Tools

- **cost-ledger** — per-session cost, sidechain (subagent) vs main split, tool-call frequency
- **cache-radar** — prompt-cache hit rate, worst-offender sessions, $ saved
- **md-lint** — CLAUDE.md / AGENTS.md linter (line cap, duplicates, hedging, contradictions)

## Run

```bash
python3 -m cctools cost-ledger --days 7
python3 -m cctools cache-radar --days 30
python3 -m cctools md-lint ~/.claude/CLAUDE.md ./CLAUDE.md
```

Or install:

```bash
pip install -e .
cost-ledger --days 7
cache-radar
md-lint .
```

## Data source

Reads `~/.claude/projects/**/*.jsonl` (Claude Code session transcripts).
No network. Local-only.
