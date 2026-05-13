"""Unified entrypoint: python -m cctools <subcommand>"""
from __future__ import annotations

import sys

USAGE = """cctools <subcommand> [args]

Subcommands:
  cost-ledger    Per-session/tool cost attribution (sidechain split)
  cache-radar    Prompt-cache hit rate + worst-offender sessions
  md-lint        Lint CLAUDE.md / AGENTS.md for bloat + contradictions
"""


def main() -> None:
    if len(sys.argv) < 2:
        print(USAGE)
        sys.exit(1)
    cmd = sys.argv.pop(1)
    if cmd in ("cost-ledger", "cost"):
        from .cost_ledger import main as m
    elif cmd in ("cache-radar", "cache"):
        from .cache_radar import main as m
    elif cmd in ("md-lint", "lint"):
        from .md_lint import main as m
    else:
        print(USAGE)
        sys.exit(1)
    m()


if __name__ == "__main__":
    main()
