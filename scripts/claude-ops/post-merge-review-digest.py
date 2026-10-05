#!/usr/bin/env python3
"""post-merge-review-digest — daily digest of PRs the user merged in the last 24h.

Finds PRs authored by the user's GitHub account and merged in the last 24h, using
`gh search prs`. Writes a digest file listing repo/PR#/title/diff link, each
marked as needing a /code-review-style pass. This script cannot itself invoke
Claude Code's /code-review skill (no shelling out to `claude` recursively) —
the digest is meant to be read by a human or fed into a future session.

Usage: post-merge-review-digest.py [--dry-run] [--username NAME] [--hours N]
"""
import argparse
import datetime as dt
import json
import subprocess
import sys
import os

HOME = os.path.expanduser("~")
REPORT_DIR = os.path.join(HOME, ".claude", "reports")
FALLBACK_USERNAME = "<your-gh-user>"


def today():
    return dt.date.today().isoformat()


def gh_username():
    try:
        r = subprocess.run(["gh", "api", "user", "--jq", ".login"],
                           capture_output=True, text=True, timeout=20)
        if r.returncode == 0 and r.stdout.strip():
            return r.stdout.strip()
    except Exception:
        pass
    return FALLBACK_USERNAME


def merged_prs(username, hours):
    since = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=hours)).strftime("%Y-%m-%d")
    cmd = ["gh", "search", "prs", "--author", username, "--merged",
           "--merged-at", f">={since}",
           "--json", "repository,number,title,url,closedAt",
           "--limit", "100"]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    if r.returncode != 0:
        raise RuntimeError(f"gh search prs failed: {r.stderr[:300]}")
    data = json.loads(r.stdout or "[]")
    cutoff = dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=hours)
    out = []
    for pr in data:
        # gh search prs --json has no mergedAt field for merged PRs; closedAt
        # is the merge time when --merged is set (the PR closed by merging).
        closed_at = pr.get("closedAt")
        if not closed_at:
            continue
        ts = dt.datetime.fromisoformat(closed_at.replace("Z", "+00:00"))
        if ts >= cutoff:
            out.append(pr)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="print digest, do not write file")
    ap.add_argument("--username", help="override GitHub username lookup")
    ap.add_argument("--hours", type=int, default=24)
    args = ap.parse_args()

    username = args.username or gh_username()

    try:
        prs = merged_prs(username, args.hours)
    except Exception as e:
        print(f"post-merge-review-digest: FAILED ({e})", file=sys.stderr)
        return 1

    lines = [f"# Merged PR digest — {today()}", "",
             f"PRs merged by {username} in the last {args.hours}h. "
             "Each needs a /code-review-style pass (not run automatically).", ""]

    if not prs:
        lines.append("No PRs merged in this window.")
    else:
        for pr in prs:
            repo = pr.get("repository", {}).get("nameWithOwner", "?")
            lines.append(f"- [ ] {repo}#{pr.get('number','?')}: {pr.get('title','')} "
                         f"({pr.get('url','')}) diff: {pr.get('url','')}/files")

    summary = f"post-merge-review-digest: {len(prs)} PR(s) merged by {username} in last {args.hours}h"

    if args.dry_run:
        print(summary + " (dry-run, not written)")
        print("\n".join(lines))
        return 0

    os.makedirs(REPORT_DIR, exist_ok=True)
    report_path = os.path.join(REPORT_DIR, f"merged-prs-{today()}.md")
    with open(report_path, "w") as f:
        f.write("\n".join(lines) + "\n")

    print(f"{summary} -> {report_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
