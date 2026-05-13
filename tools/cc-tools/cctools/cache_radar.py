"""cache-radar: prompt-cache efficiency per session + global rollup."""
from __future__ import annotations

import argparse
import time
from collections import defaultdict

from .jsonl import extract_usage, iter_events, session_files


def run(days: int = 7, top: int = 20) -> None:
    cutoff = time.time() - days * 86400
    by_session: dict[str, dict] = defaultdict(
        lambda: {"read": 0, "create": 0, "input": 0, "output": 0}
    )

    for path in session_files():
        if path.stat().st_mtime < cutoff:
            continue
        for ev in iter_events(path):
            u = extract_usage(ev)
            if not u:
                continue
            s = by_session[u["session"] or path.stem]
            s["read"] += u["cache_read"]
            s["create"] += u["cache_create"]
            s["input"] += u["input"]
            s["output"] += u["output"]

    total_read = sum(s["read"] for s in by_session.values())
    total_create = sum(s["create"] for s in by_session.values())
    total_input = sum(s["input"] for s in by_session.values())
    total_billable_in = total_read + total_create + total_input
    hit_rate = total_read / total_billable_in if total_billable_in else 0.0
    saved_usd = total_read * (3.0 - 0.30) / 1_000_000  # sonnet baseline

    print(f"\n=== cache-radar (last {days}d) ===\n")
    print(f"Cache reads:    {total_read:>14,}")
    print(f"Cache creates:  {total_create:>14,}")
    print(f"Raw input:      {total_input:>14,}")
    print(f"Hit rate:       {hit_rate:>14.1%}")
    print(f"Est. savings:   ${saved_usd:>13.2f}  (sonnet-equivalent, vs zero-cache baseline)")

    print(f"\n=== worst cache offenders (top {top} — high create, low read) ===\n")
    rows = []
    for sid, s in by_session.items():
        bill = s["read"] + s["create"] + s["input"]
        if bill < 1000:
            continue
        rate = s["read"] / bill if bill else 0.0
        rows.append((sid, s, rate))
    rows.sort(key=lambda r: (r[2], -r[1]["create"]))
    print(f"{'session':<40} {'reads':>10} {'creates':>10} {'hit%':>8}")
    print("-" * 70)
    for sid, s, rate in rows[:top]:
        print(f"{sid[:40]:<40} {s['read']:>10,} {s['create']:>10,} {rate:>7.1%}")

    if hit_rate < 0.5:
        print("\nHINT: hit rate < 50%. Likely cause: CLAUDE.md churn, dynamic injection, or short sessions.")
    elif hit_rate < 0.75:
        print("\nHINT: hit rate ok. Push higher by stabilizing CLAUDE.md and tool/skill order.")
    else:
        print("\nHINT: hit rate healthy.")


def main() -> None:
    p = argparse.ArgumentParser(prog="cache-radar")
    p.add_argument("--days", type=int, default=7)
    p.add_argument("--top", type=int, default=20)
    args = p.parse_args()
    run(args.days, args.top)


if __name__ == "__main__":
    main()
