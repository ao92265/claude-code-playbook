#!/usr/bin/env python3
"""incident-replay.py - replay past incidents against the code reviewer and score it.

Every case under ~/.claude/incident-replay/cases/<slug>/ is a bad change that once
got through (change.diff) plus the finding a good review must make (expect.txt).
The code-reviewer agent reviews each diff. A cheap judge model decides whether the
review made that finding. The score goes into an append-only ledger.

The rule this exists for (from Anthropic's "how the Claude Code team does code
review", 15 Oct 2026): a change to the review prompt, a hook or the model stays
only if this score holds or goes up. Run it before and after the change.

Usage:
  incident-replay.py              all cases, alert on a drop
  incident-replay.py --case SLUG  one case (no baseline unless the set matches)

Exit: 0 held or rose (or no baseline yet), 1 score dropped, 3 incomplete
(a reviewer or judge call failed, so the run is not a measurement).

An errored case is recorded as an error, never as a miss. A dead instrument and a
real zero must not look the same (see memory: launchd-jobs-cannot-use-applescript).

Env (tests only): INCIDENT_CLAUDE_BIN, INCIDENT_HOME, INCIDENT_CASES, INCIDENT_NO_ALERT=1.
"""
import argparse
import traceback
import datetime
import hashlib
import json
import re
import os
import subprocess
import sys
import urllib.parse
import urllib.request

HOME = os.path.expanduser("~")
BASE = os.environ.get("INCIDENT_HOME") or os.path.join(HOME, ".claude", "incident-replay")
CASES = os.environ.get("INCIDENT_CASES") or os.path.join(HOME, ".claude", "incident-replay", "cases")
LEDGER = os.path.join(BASE, "ledger.jsonl")
WORK = os.path.join(BASE, "work")
CLAUDE = os.environ.get("INCIDENT_CLAUDE_BIN") or "claude"
AGENT_FILE = os.path.join(HOME, ".claude", "agents", "code-reviewer.md")
BOT_ENV = os.path.join(HOME, "Repos", "mybot", ".env")
REVIEW_MODEL = "opus"
JUDGE_MODEL = "haiku"
TIMEOUT = 600

REVIEW_PROMPT = """Review this change. You have no repository access: the diff is all
there is. Report every defect you find, most severe first, one per bullet, each with
the line it is on and why it is wrong.

```diff
{diff}
```"""

JUDGE_PROMPT = """JUDGE THIS REVIEW. A code review was run on a change that contains
one known defect. Decide whether the review identified THAT defect. Wording does not
matter; the mechanism must be there. A vague nearby remark does not count.

Known defect:
{expect}

Review:
<<<
{review}
>>>

Answer with exactly CAUGHT or MISSED on the first line, then one line of reason."""


def call_claude(prompt, extra):
    """One headless call. Returns stdout, or None when the call itself failed."""
    os.makedirs(WORK, exist_ok=True)
    try:
        r = subprocess.run([CLAUDE, "-p", "--output-format", "text",
                            "--no-session-persistence", *extra],
                           input=prompt, capture_output=True, text=True,
                           timeout=TIMEOUT, cwd=WORK)
    except (subprocess.TimeoutExpired, OSError):
        return None
    if r.returncode != 0 or not r.stdout.strip():
        return None
    return r.stdout


def parse_verdict(text):
    """CAUGHT or MISSED from the first line ("Verdict: CAUGHT." counts). Both or
    neither is no verdict."""
    first = (text or "").strip().splitlines()[:1]
    words = set(re.findall(r"[A-Z]+", first[0].upper())) if first else set()
    hits = words & {"CAUGHT", "MISSED"}
    return hits.pop() if len(hits) == 1 else None


def run_case(slug):
    d = os.path.join(CASES, slug)
    try:
        with open(os.path.join(d, "change.diff")) as f:
            diff = f.read()
        with open(os.path.join(d, "expect.txt")) as f:
            expect = f.read().strip()
    except OSError as e:
        return {"case": slug, "result": "error", "why": f"case files: {e.strerror}"}
    review = call_claude(REVIEW_PROMPT.format(diff=diff),
                         ["--agent", "code-reviewer", "--model", REVIEW_MODEL, "--tools", ""])
    if review is None:
        return {"case": slug, "result": "error", "why": "reviewer call failed"}
    raw = call_claude(JUDGE_PROMPT.format(expect=expect, review=review),
                      # No user settings, so no per-prompt hooks: on 20 Oct the
                      # open-question hook made the judge answer a different question.
                      # The reviewer keeps them (its agent file needs user settings,
                      # and that is how it really runs).
                      ["--setting-sources", "", "--model", JUDGE_MODEL, "--tools", ""])
    verdict = parse_verdict(raw)
    if verdict is None:
        return {"case": slug, "result": "error", "why": "judge gave no verdict",
                "judge": (raw or "")[:200]}
    return {"case": slug, "result": verdict.lower(), "review": review[:4000]}


FINGERPRINT_FILES = (AGENT_FILE, os.path.join(HOME, ".claude", "settings.json"),
                     os.path.join(HOME, ".claude", "CLAUDE.md"))


def fingerprint():
    """What the score measures: the reviewer agent, the hooks and rules it runs
    under (settings.json, CLAUDE.md), both models and both prompts. When this
    changes between runs, a score move is caused by that change. A model alias
    pointing at a newer model is NOT visible here."""
    h = hashlib.sha256()
    for path in FINGERPRINT_FILES:
        try:
            with open(path, "rb") as f:
                h.update(f.read())
        except OSError:
            h.update(b"missing:" + path.encode())
    for part in (REVIEW_MODEL, REVIEW_PROMPT, JUDGE_MODEL, JUDGE_PROMPT):
        h.update(part.encode())
    return h.hexdigest()[:12]


BASELINE_DAYS = 7


def ledger_rows():
    """Every readable ledger row. A corrupt line (a partial write) is skipped, not fatal."""
    rows = []
    try:
        with open(LEDGER) as f:
            for line in f:
                try:
                    rows.append(json.loads(line))
                except ValueError:
                    continue
    except OSError:
        pass
    return rows


def baseline(case_ids):
    """Best complete run over the same case set in the last week. Best, not last,
    so a drop does not quietly become the new bar the day after it is alerted.
    Errored runs are never baselines."""
    since = (datetime.datetime.now() - datetime.timedelta(days=BASELINE_DAYS)).isoformat()
    best = None
    for r in ledger_rows():
        if not isinstance(r, dict) or r.get("errors") != 0 or str(r.get("at", "")) < since:
            continue
        if sorted(r.get("cases", [])) != sorted(case_ids):
            continue
        if best is None or r.get("caught", 0) >= best.get("caught", 0):
            best = r
    return best


def send_telegram(text):
    if os.environ.get("INCIDENT_NO_ALERT") == "1" or not os.path.exists(BOT_ENV):
        return
    tok = chat = None
    with open(BOT_ENV) as f:
        for line in f:
            if line.startswith("TELEGRAM_BOT_TOKEN="):
                tok = line.split("=", 1)[1].strip().strip("\"'")
            elif line.startswith("TELEGRAM_ALLOWED_USER_IDS="):
                chat = line.split("=", 1)[1].strip().strip("\"'").split(",")[0]
    if not tok or not chat:
        return
    data = urllib.parse.urlencode({"chat_id": chat, "text": text[:4000]}).encode()
    try:
        urllib.request.urlopen(urllib.request.Request(
            f"https://api.telegram.org/bot{tok}/sendMessage", data=data), timeout=25)
    except Exception:
        pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--case")
    args = ap.parse_args()
    slugs = sorted(s for s in os.listdir(CASES)
                   if os.path.isdir(os.path.join(CASES, s)) and not s.startswith("."))
    if args.case:
        if args.case not in slugs:
            print(f"no such case: {args.case}", file=sys.stderr)
            return 2
        slugs = [args.case]

    prev = baseline(slugs)
    results = [run_case(s) for s in slugs]
    caught = sum(r["result"] == "caught" for r in results)
    errors = sum(r["result"] == "error" for r in results)
    row = {"at": datetime.datetime.now().isoformat(timespec="seconds"),
           "fingerprint": fingerprint(), "model": REVIEW_MODEL, "cases": slugs,
           "total": len(slugs), "caught": caught, "errors": errors,
           "results": results}
    os.makedirs(BASE, exist_ok=True)
    with open(LEDGER, "a") as f:
        f.write(json.dumps(row) + "\n")

    for r in results:
        print(f"  {r['result']:<7} {r['case']}" + (f"  ({r['why']})" if r.get("why") else ""))
    print(f"score {caught}/{len(slugs)}, errors {errors}, fingerprint {row['fingerprint']}")

    if errors:
        msg = (f"Incident replay INCOMPLETE: {errors} of {len(slugs)} calls failed "
               "(login, limit or outage). Not a measurement.")
        print(msg)
        send_telegram(msg)
        return 3
    if prev is None:
        print("no baseline for this case set yet")
        return 0
    if caught < prev["caught"]:
        lost = sorted({r["case"] for r in prev["results"] if r["result"] == "caught"}
                      - {r["case"] for r in results if r["result"] == "caught"})
        changed = "reviewer CHANGED since last run" if row["fingerprint"] != prev["fingerprint"] \
            else "reviewer unchanged (model drift or a flaky judge)"
        msg = (f"Incident replay score DROPPED {prev['caught']} to {caught} of {len(slugs)}. "
               f"{changed}. Now missed: {', '.join(lost) or 'n/a'}")
        print(msg)
        send_telegram(msg)
        return 1
    print(f"held or rose (was {prev['caught']})")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        # Exit 1 means "score dropped". A crash must never look like that.
        traceback.print_exc()
        send_telegram("Incident replay CRASHED, no score today. See ~/.claude/incident-replay/launchd.log")
        sys.exit(3)
