"""cost-ledger: per-session / per-tool / sidechain cost attribution."""
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path

from .jsonl import (
    cost_usd,
    extract_tool_uses,
    extract_usage,
    iter_events,
    session_files,
)


def run(days: int = 7, top: int = 20, project: str | None = None) -> None:
    import time

    cutoff = time.time() - days * 86400
    by_session: dict[str, dict] = defaultdict(
        lambda: {"cost": 0.0, "main": 0.0, "side": 0.0, "tools": defaultdict(int), "model": ""}
    )
    by_tool: dict[str, float] = defaultdict(float)

    for path in session_files():
        if project and project not in str(path):
            continue
        if path.stat().st_mtime < cutoff:
            continue
        for ev in iter_events(path):
            u = extract_usage(ev)
            if u:
                c = cost_usd(u)
                sid = u["session"] or path.stem
                by_session[sid]["cost"] += c
                if u["is_sidechain"]:
                    by_session[sid]["side"] += c
                else:
                    by_session[sid]["main"] += c
                by_session[sid]["model"] = u.get("model", "") or by_session[sid]["model"]
            for tname in extract_tool_uses(ev):
                sid = ev.get("sessionId") or path.stem
                by_session[sid]["tools"][tname] += 1
                by_tool[tname] += 1

    rows = sorted(by_session.items(), key=lambda kv: -kv[1]["cost"])[:top]
    total = sum(v["cost"] for v in by_session.values())
    print(f"\n=== cost-ledger (last {days}d, {len(by_session)} sessions, ${total:.2f}) ===\n")
    print(f"{'session':<40} {'model':<20} {'main$':>8} {'side$':>8} {'total$':>8}")
    print("-" * 88)
    for sid, v in rows:
        print(
            f"{sid[:40]:<40} {(v['model'] or '?')[:20]:<20} "
            f"{v['main']:>8.3f} {v['side']:>8.3f} {v['cost']:>8.3f}"
        )

    print(f"\n=== tool call frequency (top {top}) ===\n")
    tools = sorted(by_tool.items(), key=lambda kv: -kv[1])[:top]
    for name, n in tools:
        print(f"  {n:>6}  {name}")


def main() -> None:
    p = argparse.ArgumentParser(prog="cost-ledger")
    p.add_argument("--days", type=int, default=7)
    p.add_argument("--top", type=int, default=20)
    p.add_argument("--project", help="substring filter on project path")
    args = p.parse_args()
    run(args.days, args.top, args.project)


if __name__ == "__main__":
    main()
