#!/usr/bin/env python3
"""memory-consolidate — flags likely-duplicate or stale memory files.

Read-only against ~/.claude/projects/-Users-you/memory/*.md. Never edits
MEMORY.md or any memory file — that index is shared by every live session and
a wholesale write deletes other sessions' entries (see MEMORY.md itself).
Writes a proposal report only; a human decides what to merge or delete.

Duplicate detection: Jaccard overlap on word-shingles between file bodies.
Stale detection: file not modified in STALE_DAYS and its slug does not appear
in MEMORY.md's current index (meaning it may have already been dropped from
rotation but the file itself was never removed).

Usage: memory-consolidate.py [--dry-run] [--overlap PCT] [--stale-days N]
"""
import argparse
import datetime as dt
import glob
import os
import re
import sys

HOME = os.path.expanduser("~")
CFG = os.path.join(HOME, ".claude")
MEMDIR = os.path.join(CFG, "projects", "-Users-you", "memory")
MEMORY_INDEX = os.path.join(MEMDIR, "MEMORY.md")
REPORT_DIR = os.path.join(CFG, "reports")
STALE_DAYS_DEFAULT = 90
OVERLAP_DEFAULT = 60  # percent


def today():
    return dt.date.today().isoformat()


def shingles(text, n=4):
    words = re.findall(r"[a-z0-9]+", text.lower())
    if len(words) < n:
        return {tuple(words)} if words else set()
    return {tuple(words[i:i + n]) for i in range(len(words) - n + 1)}


def jaccard(a, b):
    if not a or not b:
        return 0.0
    inter = len(a & b)
    union = len(a | b)
    return inter / union if union else 0.0


def slug_of(path):
    base = os.path.basename(path)[:-3]  # strip .md
    return re.sub(r"-\d{4}-\d{2}-\d{2}$", "", base)


def indexed_slugs():
    """Slugs currently referenced as (slug).md links in MEMORY.md."""
    if not os.path.exists(MEMORY_INDEX):
        return set()
    with open(MEMORY_INDEX) as f:
        text = f.read()
    return set(re.findall(r"\(([\w-]+)\.md\)", text))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="print summary, skip writing report")
    ap.add_argument("--overlap", type=int, default=OVERLAP_DEFAULT,
                     help="Jaccard overlap %% above which two files are flagged duplicate")
    ap.add_argument("--stale-days", type=int, default=STALE_DAYS_DEFAULT)
    args = ap.parse_args()

    files = sorted(glob.glob(os.path.join(MEMDIR, "*.md")))
    files = [f for f in files if os.path.basename(f) != "MEMORY.md"]
    if not files:
        print(f"memory-consolidate: no memory files found under {MEMDIR}")
        return 0

    indexed = indexed_slugs()
    now = dt.datetime.now().timestamp()

    bodies = {}
    for f in files:
        try:
            with open(f, errors="replace") as fh:
                bodies[f] = fh.read()
        except Exception:
            bodies[f] = ""
    shingle_sets = {f: shingles(b) for f, b in bodies.items()}

    dup_pairs = []
    for i, a in enumerate(files):
        for b in files[i + 1:]:
            slug_a, slug_b = slug_of(a), slug_of(b)
            score = jaccard(shingle_sets[a], shingle_sets[b])
            same_topic = slug_a == slug_b or slug_a in slug_b or slug_b in slug_a
            if score * 100 >= args.overlap or (same_topic and score * 100 >= args.overlap / 2):
                dup_pairs.append((a, b, round(score * 100)))

    stale = []
    for f in files:
        age_days = (now - os.path.getmtime(f)) / 86400
        slug = slug_of(f)
        if age_days >= args.stale_days and slug not in indexed:
            stale.append((f, round(age_days)))

    if not dup_pairs and not stale:
        print(f"memory-consolidate: {len(files)} files scanned, nothing flagged")
        return 0

    lines = [f"# memory-consolidate proposal — {today()}", "",
             f"{len(files)} memory files scanned under {MEMDIR}. "
             "Report-only: no file was merged, edited, or deleted.", ""]

    if dup_pairs:
        lines.append("## Candidate duplicate/overlap pairs")
        for a, b, score in sorted(dup_pairs, key=lambda x: -x[2]):
            lines.append(f"- {os.path.basename(a)} <-> {os.path.basename(b)}: "
                         f"{score}% shingle overlap")
        lines.append("")

    if stale:
        lines.append(f"## Candidate stale files (unmodified {args.stale_days}+ days, "
                     "slug not found in MEMORY.md index)")
        for f, age in sorted(stale, key=lambda x: -x[1]):
            lines.append(f"- {os.path.basename(f)}: last modified {age} days ago")
        lines.append("")

    report_path = os.path.join(REPORT_DIR, f"memory-consolidate-{today()}.md")
    if not args.dry_run:
        os.makedirs(REPORT_DIR, exist_ok=True)
        with open(report_path, "w") as f:
            f.write("\n".join(lines))
        print(f"memory-consolidate: {len(dup_pairs)} duplicate pair(s), {len(stale)} stale "
              f"candidate(s) -> {report_path}")
    else:
        print(f"memory-consolidate (dry-run): {len(dup_pairs)} duplicate pair(s), "
              f"{len(stale)} stale candidate(s), report not written")

    return 0


if __name__ == "__main__":
    sys.exit(main())
