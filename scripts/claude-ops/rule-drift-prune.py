#!/usr/bin/env python3
"""rule-drift-prune — turns rule-drift.py's weekly scores into a removal proposal.

rule-drift.py scores compliance per rule per week. This script keeps its own
small run-history log (one line per invocation), and once a rule has scored
below the floor for 3 consecutive weekly runs of THIS script, it drafts a
proposed CLAUDE.md-family removal: the rule text (grepped from the imported
rule files), the 3-week trend, and a rationale. It writes the proposal to a
file under ~/.claude/reports/ and NEVER edits CLAUDE.md or any imported file
itself — matching core-rules.md's "no destructive action without asking".

Usage: rule-drift-prune.py [--dry-run] [--floor PCT] [--min-samples N]
"""
import argparse
import datetime as dt
import glob
import json
import os
import re
import subprocess
import sys

HOME = os.path.expanduser("~")
CFG = os.path.join(HOME, ".claude")
DIR = os.path.join(CFG, "rule-drift-prune")
HISTORY = os.path.join(DIR, "history.jsonl")
REPORT_DIR = os.path.join(CFG, "reports")
RULE_DRIFT = os.path.join(CFG, "scripts", "rule-drift.py")

# Files whose text a proposed rule might live in — searched for the rule's
# match string so the proposal can cite something concrete.
RULE_FILES = [
    os.path.join(HOME, ".claude", "CLAUDE.md"),
    os.path.join(HOME, ".claude", "core-rules.md"),
    os.path.join(HOME, ".claude", "RTK.md"),
    os.path.join(HOME, ".claude", "factual-guardrails.md"),
    os.path.join(HOME, ".claude", "workflow-rules.md"),
    os.path.join(HOME, ".claude", "design-rules.md"),
]

MATCH_STRINGS = {
    "status-light": "Begin every reply with a status light",
    "answer-shape:no-preamble": "ANSWER SHAPE",
    "answer-shape:list-cap": "ANSWER SHAPE",
    "caveman": "CAVEMAN MODE",
    "research-only": "RESEARCH-ONLY",
    "probe-first": "Probe first",
}


def today():
    return dt.date.today().isoformat()


def pct(ok, n):
    return round(100 * ok / n) if n else None


def run_rule_drift(floor, min_samples):
    r = subprocess.run(
        ["/opt/homebrew/bin/python3", RULE_DRIFT, "--json", "--floor", str(floor),
         "--min-samples", str(min_samples)],
        capture_output=True, text=True, timeout=120,
    )
    if r.returncode != 0:
        raise RuntimeError(f"rule-drift.py --json exited {r.returncode}: {r.stderr[:300]}")
    return json.loads(r.stdout)


def flagged_this_run(agg, floor, min_samples):
    """Rules whose most recent completed week is below floor, with enough samples."""
    flagged = {}
    for key, a in agg.items():
        weeks = sorted(a.get("weeks", {}).items())
        if not weeks:
            continue
        wk, (n, ok) = weeks[-1]
        if n < min_samples:
            continue
        p = pct(ok, n)
        if p is not None and p < floor:
            flagged[key] = {"week": wk, "pct": p, "n": n}
    return flagged


def load_history():
    rows = []
    if os.path.exists(HISTORY):
        with open(HISTORY) as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        rows.append(json.loads(line))
                    except Exception:
                        pass
    return rows


def append_history(row):
    os.makedirs(DIR, exist_ok=True)
    with open(HISTORY, "a") as f:
        f.write(json.dumps(row) + "\n")


def consecutive_streak(history, key, current_flagged):
    """How many of the most recent runs (this one included) flagged `key`."""
    streak = 1 if current_flagged else 0
    for row in reversed(history):
        if key in row.get("flagged", {}):
            streak += 1
        else:
            break
    return streak


def find_rule_text(key):
    match = MATCH_STRINGS.get(key)
    if not match:
        return None
    for path in RULE_FILES:
        if not os.path.exists(path):
            continue
        try:
            with open(path) as f:
                lines = f.readlines()
        except Exception:
            continue
        for i, line in enumerate(lines):
            if match.lower() in line.lower():
                return f"{path}:{i+1}: {line.strip()}"
    return None


def build_proposal(candidates, history):
    lines = [f"# rule-drift-prune proposal — {today()}", "",
              "Rules scoring below floor for 3+ consecutive weekly runs of this "
              "script. NOT applied — review and edit CLAUDE.md/imported files by hand.",
              ""]
    for key, info in candidates.items():
        streak = info["streak"]
        cite = find_rule_text(key) or "(rule text not found by grep, locate manually)"
        lines.append(f"## {key}")
        lines.append(f"- Flagged in last {streak} consecutive runs")
        lines.append(f"- Most recent week {info['week']}: {info['pct']}% "
                      f"compliance over {info['n']} scored samples (below floor)")
        lines.append(f"- Located at: {cite}")
        lines.append("")
        lines.append("### Proposed diff (draft — not applied)")
        lines.append("```diff")
        lines.append(f"- {cite.split(': ', 1)[-1] if ': ' in cite else '<rule line>'}")
        lines.append("```")
        lines.append("")
        lines.append("### Rationale")
        lines.append(f"Ignored for {streak} consecutive weekly checks below the "
                      f"{info['pct']}% floor. Per CLAUDE.md core-rules: "
                      "\"A rule ignored for 3 sessions gets deleted or hooked.\" "
                      "This rule is either not enforceable as prose or needs a "
                      "hook instead of a text rule.")
        lines.append("")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="do not write history, only report")
    ap.add_argument("--floor", type=int, default=80)
    ap.add_argument("--min-samples", type=int, default=10)
    args = ap.parse_args()

    try:
        agg = run_rule_drift(args.floor, args.min_samples)
    except Exception as e:
        print(f"rule-drift-prune: FAILED to run rule-drift.py ({e})", file=sys.stderr)
        return 1

    flagged = flagged_this_run(agg, args.floor, args.min_samples)
    history = load_history()

    candidates = {}
    for key, info in flagged.items():
        streak = consecutive_streak(history, key, True)
        if streak >= 3:
            candidates[key] = {**info, "streak": streak}

    os.makedirs(REPORT_DIR, exist_ok=True)
    report_path = os.path.join(REPORT_DIR, f"rule-drift-prune-{today()}.md")
    if candidates:
        with open(report_path, "w") as f:
            f.write(build_proposal(candidates, history))
        summary = (f"rule-drift-prune: {len(flagged)} flagged this run, "
                   f"{len(candidates)} proposal(s) written -> {report_path}")
    else:
        summary = (f"rule-drift-prune: {len(flagged)} flagged this run, "
                   f"0 at 3-week streak, no proposal written")

    if not args.dry_run:
        append_history({"ts": dt.datetime.now().isoformat(timespec="seconds"),
                         "flagged": flagged})

    print(summary)
    return 0


if __name__ == "__main__":
    sys.exit(main())
