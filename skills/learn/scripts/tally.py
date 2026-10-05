#!/usr/bin/env python3
"""Tally ~/.claude/feedback.jsonl by tag and split into promote / watch / prune.

Why: corrections are captured automatically (correction-detect.sh, feedback-marker.sh)
but nothing ever counts them, so a one-off gripe and a real pattern look identical and
every rule file only grows. A tag has to reach the threshold before it earns a rule.

Prints a report. Writes nothing. Exit 0 always.
"""
import argparse
import collections
import datetime as dt
import difflib
import json
import os
import sys

DEFAULT_LOG = os.path.expanduser("~/.claude/feedback.jsonl")
THRESHOLD = 3
STALE_DAYS = 30
NEAR_DUP_RATIO = 0.75
# Buckets the detector assigns to anything it cannot classify. A high count here is a
# measure of how often the user pushed back, not a description of one behaviour, so it can
# never be promoted straight to a rule.
CATCH_ALL = {"wholesale rejection", "direct contradiction", "told to stop doing something"}


def load(path):
    rows = []
    if not os.path.exists(path):
        return rows
    with open(path, encoding="utf-8", errors="ignore") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return rows


def norm(note):
    return " ".join((note or "").strip().lower().split())[:60]


def days_since(ts):
    if not ts:
        return None
    try:
        stamp = dt.datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except ValueError:
        return None
    now = dt.datetime.now(dt.timezone.utc)
    return (now - stamp).days


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", default=DEFAULT_LOG)
    ap.add_argument("--threshold", type=int, default=THRESHOLD)
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    args = ap.parse_args()

    rows = load(args.log)
    if not rows:
        print(f"No feedback found at {args.log}")
        return 0

    tags = collections.defaultdict(list)
    for r in rows:
        if r.get("verdict") != "down":
            continue
        tags[norm(r.get("note")) or "(no note)"].append(r)

    stats = {}
    for tag, entries in tags.items():
        stamps = sorted(e.get("ts", "") for e in entries if e.get("ts"))
        cwds = collections.Counter(
            os.path.basename(e.get("cwd", "")) for e in entries if e.get("cwd")
        )
        stats[tag] = {
            "count": len(entries),
            "first": stamps[0][:10] if stamps else "",
            "last": stamps[-1][:10] if stamps else "",
            "age_days": days_since(stamps[-1]) if stamps else None,
            "repos": [c for c, _ in cwds.most_common(3)],
            "catch_all": tag in CATCH_ALL,
        }

    # Near-duplicate tags split one real pattern across two counts and defeat the
    # threshold, so surface them for merge before anything is promoted.
    names = sorted(stats)
    dupes = []
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            if a == "(no note)" or b == "(no note)":
                continue
            if difflib.SequenceMatcher(None, a, b).ratio() >= NEAR_DUP_RATIO:
                dupes.append((a, b, stats[a]["count"] + stats[b]["count"]))

    promote, watch, prune = [], [], []
    for tag, s in stats.items():
        if tag == "(no note)":
            continue
        if s["count"] >= args.threshold:
            promote.append((tag, s))
        elif s["age_days"] is not None and s["age_days"] > STALE_DAYS:
            prune.append((tag, s))
        else:
            watch.append((tag, s))

    promote.sort(key=lambda x: -x[1]["count"])
    watch.sort(key=lambda x: -x[1]["count"])
    prune.sort(key=lambda x: x[1]["age_days"] or 0, reverse=True)

    if args.json:
        json.dump(
            {
                "threshold": args.threshold,
                "total": len(rows),
                "promote": [{"tag": t, **s} for t, s in promote],
                "watch": [{"tag": t, **s} for t, s in watch],
                "prune": [{"tag": t, **s} for t, s in prune],
                "near_duplicates": [{"a": a, "b": b, "combined": c} for a, b, c in dupes],
            },
            sys.stdout,
            indent=1,
        )
        print()
        return 0

    print(f"Feedback log: {args.log}  ({len(rows)} entries, threshold {args.threshold})\n")

    print(f"PROMOTE — at or above {args.threshold} strikes, earns a rule")
    if not promote:
        print("  (nothing)")
    for tag, s in promote:
        flag = "  [CATCH-ALL: ask before promoting]" if s["catch_all"] else ""
        where = f"  seen in: {', '.join(s['repos'])}" if s["repos"] else ""
        print(f"  {s['count']:3d}  {tag:38s} {s['first']} to {s['last']}{flag}{where}")

    print(f"\nWATCH — under {args.threshold}, still live")
    if not watch:
        print("  (nothing)")
    for tag, s in watch:
        print(f"  {s['count']:3d}  {tag:38s} last {s['last']}")

    print(f"\nPRUNE — under {args.threshold} and untouched for over {STALE_DAYS} days")
    if not prune:
        print("  (nothing)")
    for tag, s in prune:
        print(f"  {s['count']:3d}  {tag:38s} last {s['last']} ({s['age_days']}d ago)")

    if dupes:
        print("\nNEAR-DUPLICATE TAGS — merge these before counting")
        for a, b, combined in dupes:
            print(f"  '{a}' + '{b}'  would be {combined}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
