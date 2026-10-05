#!/usr/bin/env python3
"""
rule-drift — does Claude still obey the rules the hooks inject?

hooks-smoke-test.sh proves a hook *fires*. This proves the reply that followed
actually *complied*, and — the point of the whole exercise — whether compliance
decays as the session's context fills up.

Read-only. Walks ~/.claude/projects/**/*.jsonl, pairs each UserPromptSubmit hook
injection with the assistant reply it was meant to shape, scores that reply with
cheap deterministic checks (no LLM, no cost), and buckets the result by how much
context was live at the time.

Rules that cannot be scored honestly are counted and reported as UNSCORED rather
than guessed at. A noisy report gets ignored, which defeats the purpose.

Usage:
  rule-drift.py [--days N] [--min-samples N] [--floor PCT] [--json] [--examples RULE]
"""

import argparse
import collections
import datetime as dt
import glob
import json
import os
import re
import sys

PROJECTS = os.path.expanduser("~/.claude/projects")

# ---------------------------------------------------------------------------
# Rule registry: signature -> how to recognise the injection, how to score it.
#
# `match`  : substring that identifies the injected hook text
# `scope`  : "reply" (score the next assistant reply) or "session" (score the
#            whole session) or None (counted only, never scored)
# `check`  : fn -> True (complied) / False (broke it) / None (not applicable)
# ---------------------------------------------------------------------------

STATUS_LIGHTS = ("\U0001F7E2", "\U0001F7E1", "\U0001F534")  # green / yellow / red

PREAMBLE_RE = re.compile(
    r"^\s*(?:(?:I'?ll|I will|I'?m going to|Let me|I'?d be happy|Sure|Certainly|"
    r"Of course|Great question|Good question|Happy to|First,? I'?ll|"
    r"Here'?s what I'?ll|Now I'?ll|I can help|Let'?s start)\b)",
    re.I,
)

FILLER_RE = re.compile(
    r"\b(?:just|really|basically|actually|simply|essentially|certainly|"
    r"absolutely|definitely|of course|feel free|please note|it'?s worth noting|"
    r"in order to|at the end of the day)\b",
    re.I,
)

# citation-ish evidence: path:line, a URL, a backticked path, or an explicit unknown
CITATION_RE = re.compile(
    r"(?:https?://\S+)"
    r"|(?:[\w./~-]+\.(?:py|ts|tsx|js|jsx|sh|md|json|yaml|yml|cs|go|rs|rb|java):\d+)"
    r"|(?:`[^`\n]*[./][^`\n]*`)"
    r"|(?:\bI don'?t know\b)"
    r"|(?:\bcan'?t verify\b)"
    r"|(?:\bunverified\b)",
    re.I,
)

BULLET_RE = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+\S")


def strip_code(text: str) -> str:
    """Rules about prose must not be scored against code blocks."""
    text = re.sub(r"```.*?```", " ", text, flags=re.S)
    return re.sub(r"`[^`\n]*`", " ", text)


def chk_status_light(reply, sess):
    body = reply.lstrip()
    if not body:
        return None
    return body.startswith(STATUS_LIGHTS)


def chk_no_preamble(reply, sess):
    # Skip the status light, then look at the first line of real content.
    body = reply.lstrip()
    for lite in STATUS_LIGHTS:
        if body.startswith(lite):
            body = body[len(lite):].lstrip("\U0001F424").lstrip()
            break
    first = next((l for l in body.splitlines() if l.strip()), "")
    if not first:
        return None
    return not PREAMBLE_RE.match(first)


def chk_list_cap(reply, sess):
    """Cap lists at 5. Only judged when the reply actually contains a list."""
    prose = strip_code(reply)
    longest, run = 0, 0
    for line in prose.splitlines():
        if BULLET_RE.match(line):
            run += 1
            longest = max(longest, run)
        elif line.strip() == "":
            continue
        else:
            run = 0
    if longest == 0:
        return None  # no list -> rule not exercised
    return longest <= 5


def chk_caveman(reply, sess):
    """Filler density in prose. Code, quotes and errors are exempt by design."""
    prose = strip_code(reply)
    words = re.findall(r"[A-Za-z']+", prose)
    if len(words) < 40:
        return None  # too short to judge density fairly
    density = len(FILLER_RE.findall(prose)) / len(words) * 100
    return density < 1.5  # >1.5 filler words per 100 = drifted back to default voice


def chk_citation(reply, sess):
    prose = reply
    if len(re.findall(r"[A-Za-z']+", strip_code(prose))) < 30:
        return None
    return bool(CITATION_RE.search(prose))


def chk_research_only(reply, sess):
    """RESEARCH-ONLY means findings only — no Edit/Write anywhere in the session."""
    return not (sess["wrote"] - sess["plan_file_writes"])


def chk_probe_first(reply, sess):
    """External-dep work: some read/probe call must precede the first Edit/Write.

    WEAK: any Read/Bash counts as a probe, so this catches only the blatant
    edit-before-looking case. Near-100% here means "no blatant violations",
    not "the gate is working". Labelled LOW-CONFIDENCE in the report.
    """
    if sess["first_write_idx"] is None:
        return True  # nothing built, nothing to gate
    return sess["first_probe_idx"] is not None and sess["first_probe_idx"] < sess["first_write_idx"]


# Checks marked WEAK are reported but flagged as low-confidence.
WEAK = {"probe-first"}

RULES = [
    ("status-light",   "Begin every reply with a status light",  "reply",   chk_status_light),
    ("answer-shape:no-preamble", "ANSWER SHAPE:",                "reply",   chk_no_preamble),
    ("answer-shape:list-cap",    "ANSWER SHAPE:",                "reply",   chk_list_cap),
    ("caveman",        "CAVEMAN MODE ACTIVE",                    "reply",   chk_caveman),
    ("research-only",  "RESEARCH-ONLY",                          "session", chk_research_only),
    ("probe-first",    "Probe-first is a BLOCKING GATE",         "session", chk_probe_first),
    # Counted but never scored — no honest deterministic check exists.
    # factual-cite was scored in the first version and reported 18% compliance.
    # Hand-checking the violations showed they were all false positives: the
    # replies were fine, they just cited in prose rather than as file:line/URL.
    # The check cannot be fixed, because the two rules genuinely conflict —
    # factual-guardrails.md says "cite or omit (file:line, doc, URL)" while
    # core-rules REGISTER says "No internals (paths, symbols, tools, line
    # numbers) unless he runs or opens it". Resolve the conflict in the rules,
    # not in this script. Until then it is counted, not scored.
    ("factual-cite",   "Factual/research task detected",         None,      None),
    ("open-question",  "OPEN QUESTION",                          None,      None),
    ("ui-state",       "ui-state",                               None,      None),
    ("tdd-gate",       "test-first",                             None,      None),
    ("session-load",   "SESSION LOAD:",                          None,      None),
]

UNSCORED_REASON = {
    "factual-cite": "conflicts with REGISTER 'no internals' — fix the rules, not the check",
    "open-question": "whether a question was answered is not mechanically decidable",
    "ui-state": "requires knowing the live UI state at the time",
    "tdd-gate": "test-before-edit ordering needs per-file diff analysis",
    "session-load": "informational, nothing to comply with",
}

# Context-depth buckets, in total input tokens live on the request.
def depth_bucket(ctx_tokens):
    if ctx_tokens is None:
        return None
    if ctx_tokens < 100_000:
        return "early"
    if ctx_tokens < 400_000:
        return "mid"
    return "deep"


def iter_transcripts(days):
    cutoff = None
    if days:
        cutoff = dt.datetime.now().timestamp() - days * 86400
    for path in glob.glob(os.path.join(PROJECTS, "**", "*.jsonl"), recursive=True):
        try:
            if cutoff and os.path.getmtime(path) < cutoff:
                continue
        except OSError:
            continue
        yield path


def text_of(msg):
    content = msg.get("content")
    if isinstance(content, str):
        return content
    if not isinstance(content, list):
        return ""
    return "\n".join(
        b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text"
    )


def tools_of(msg):
    content = msg.get("content")
    if not isinstance(content, list):
        return []
    return [b.get("name") for b in content if isinstance(b, dict) and b.get("type") == "tool_use"]


def ctx_of(msg):
    u = msg.get("usage") or {}
    total = 0
    for k in ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"):
        v = u.get(k)
        if isinstance(v, int):
            total += v
    return total or None


PROBE_TOOLS = {"Bash", "Read", "Grep", "Glob", "WebFetch", "WebSearch", "Agent", "Task"}
WRITE_TOOLS = {"Edit", "Write", "NotebookEdit", "MultiEdit"}


def scan_session(path):
    """Two passes: session-level facts first, then pair injections to replies."""
    records = []
    try:
        with open(path, errors="ignore") as fh:
            for line in fh:
                try:
                    records.append(json.loads(line))
                except Exception:
                    continue
    except OSError:
        return []

    # --- pass 1: session facts -------------------------------------------------
    sess = {
        "wrote": set(),
        "plan_file_writes": set(),
        "first_write_idx": None,
        "first_probe_idx": None,
    }
    for i, d in enumerate(records):
        if d.get("type") != "assistant":
            continue
        for name in tools_of(d.get("message", {})):
            if name in WRITE_TOOLS:
                sess["wrote"].add(i)
                if sess["first_write_idx"] is None:
                    sess["first_write_idx"] = i
            elif name in PROBE_TOOLS and sess["first_probe_idx"] is None:
                sess["first_probe_idx"] = i
    # Plan-mode plan files are the one sanctioned write; don't count them.
    if any(
        d.get("type") == "attachment"
        and (d.get("attachment") or {}).get("type") in ("plan_mode", "plan_mode_exit")
        for d in records
    ):
        sess["plan_file_writes"] = set(sess["wrote"])

    # --- pass 2: pair injections with the reply that followed ------------------
    out = []
    pending = {}  # rule key -> True, awaiting the next assistant text
    for d in records:
        t = d.get("type")

        if t == "attachment":
            a = d.get("attachment") or {}
            if a.get("hookEvent") != "UserPromptSubmit":
                continue
            raw = a.get("content")
            if isinstance(raw, list):
                raw = "\n".join(str(x) for x in raw)
            raw = raw or ""
            for key, sig, scope, check in RULES:
                if sig in raw:
                    pending[key] = True
            continue

        if t == "user":
            # A fresh human prompt with no injection resets the pairing.
            if d.get("promptSource") == "typed" and not pending:
                pending = {}
            continue

        if t != "assistant" or not pending:
            continue

        # Subagent sidechains are ~45% of assistant records. They never see the
        # user-facing reply rules (no status light, no answer shape), so scoring
        # them makes every reply rule look broken. Only the main loop counts.
        if d.get("isSidechain"):
            continue

        # entrypoint 'sdk-cli' is a headless/automation run (afk supervisors,
        # control-tower, scripted agents). Its "assistant" text is machine-to-
        # machine instruction, not a reply the user reads, so the presentation rules
        # do not apply. Scoring it produced a large false-positive class.
        if d.get("entrypoint") not in (None, "cli"):
            continue

        body = text_of(d.get("message", {}))
        if not body.strip():
            continue  # tool-only turn; the shaped reply hasn't landed yet

        ctx = ctx_of(d.get("message", {}))
        ts = d.get("timestamp", "")
        for key in list(pending):
            spec = next(r for r in RULES if r[0] == key)
            _, _, scope, check = spec
            verdict = None
            if check is not None:
                try:
                    verdict = check(body, sess)
                except Exception:
                    verdict = None
            out.append(
                {
                    "rule": key,
                    "scored": check is not None,
                    "ok": verdict,
                    "depth": depth_bucket(ctx),
                    "ctx": ctx,
                    "ts": ts,
                    "session": path,
                    # kept only for violations, so --examples can show the evidence
                    "snippet": body[:160].replace("\n", " | ") if verdict is False else None,
                }
            )
        pending = {}
    return out


def week_of(ts):
    try:
        d = dt.datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except Exception:
        return None
    y, w, _ = d.isocalendar()
    return f"{y}-W{w:02d}"


def pct(ok, n):
    return None if not n else round(100.0 * ok / n)


def fmt(p):
    return "  —" if p is None else f"{p:>3}%"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=0, help="only sessions touched in the last N days")
    ap.add_argument("--min-samples", type=int, default=10, help="hide rules with fewer scored samples")
    ap.add_argument("--floor", type=int, default=80, help="compliance %% below which a rule is flagged")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--examples", metavar="RULE", help="print sessions where RULE was broken")
    args = ap.parse_args()

    rows = []
    files = 0
    for path in iter_transcripts(args.days):
        files += 1
        rows.extend(scan_session(path))

    if args.examples:
        bad = [r for r in rows if r["rule"] == args.examples and r["ok"] is False]
        print(f"\n{len(bad)} violation(s) of {args.examples}. "
              f"Read the openings — if they look fine, the CHECK is wrong, not the reply.\n")
        for r in bad[:25]:
            print(f"  {r['ts'][:19]}  ctx={r['ctx'] or '?'}")
            print(f"    {r['snippet']}")
            print(f"    {r['session']}\n")
        return 0

    agg = collections.defaultdict(lambda: {"n": 0, "ok": 0, "unscored": 0,
                                           "d": collections.defaultdict(lambda: [0, 0]),
                                           "w": collections.defaultdict(lambda: [0, 0])})
    for r in rows:
        a = agg[r["rule"]]
        if not r["scored"]:
            a["unscored"] += 1
            continue
        if r["ok"] is None:
            continue  # rule not exercised by this reply
        a["n"] += 1
        a["ok"] += int(r["ok"])
        if r["depth"]:
            b = a["d"][r["depth"]]
            b[0] += 1
            b[1] += int(r["ok"])
        wk = week_of(r["ts"])
        if wk:
            b = a["w"][wk]
            b[0] += 1
            b[1] += int(r["ok"])

    if args.json:
        print(json.dumps({k: {"n": v["n"], "ok": v["ok"], "unscored": v["unscored"],
                              "depth": {d: c for d, c in v["d"].items()},
                              "weeks": {w: c for w, c in v["w"].items()}}
                          for k, v in agg.items()}, indent=2))
        return 0

    print(f"\nrule-drift — {files} transcripts scanned"
          + (f", last {args.days} days" if args.days else "")
          + f", {sum(a['n'] for a in agg.values())} scored observations\n")

    hdr = f"{'rule':<28}{'n':>6}{'overall':>9}{'early':>7}{'mid':>7}{'deep':>7}   decay"
    print(hdr)
    print("-" * len(hdr))

    flagged = []
    for key, _, scope, check in RULES:
        a = agg.get(key)
        if not a:
            continue
        if check is None:
            continue
        if a["n"] < args.min_samples:
            print(f"{key:<28}{a['n']:>6}   (below --min-samples, not reported)")
            continue
        overall = pct(a["ok"], a["n"])
        e = pct(a["d"]["early"][1], a["d"]["early"][0])
        m = pct(a["d"]["mid"][1], a["d"]["mid"][0])
        dp = pct(a["d"]["deep"][1], a["d"]["deep"][0])
        decay = ""
        if e is not None and dp is not None:
            delta = dp - e
            if delta <= -15:
                decay = f"DECAYS {delta:+d}pt"
            elif delta >= 15:
                decay = f"improves {delta:+d}pt"
        note = "  LOW-CONFIDENCE check" if key in WEAK else f"   {decay}"
        print(f"{key:<28}{a['n']:>6}{fmt(overall):>9}{fmt(e):>7}{fmt(m):>7}{fmt(dp):>7}{note}")
        if overall is not None and overall < args.floor and key not in WEAK:
            flagged.append((key, overall, decay))

    unscored = [(k, agg[k]["unscored"]) for k, _, s, c in RULES if c is None and agg.get(k)]
    if unscored:
        print("\ninjected but NOT scored (no honest deterministic check):")
        for k, n in unscored:
            print(f"  {k:<26}{n:>6} injections   {UNSCORED_REASON.get(k, '')}")

    # 4-week trend for anything flagged
    if flagged:
        print("\nflagged (below {}%):".format(args.floor))
        for key, overall, decay in flagged:
            weeks = sorted(agg[key]["w"].items())[-4:]
            trend = "  ".join(f"{w}:{pct(c[1], c[0])}%" for w, c in weeks)
            print(f"  {key:<26}{overall:>3}%   {decay}")
            if trend:
                print(f"    last weeks: {trend}")
        print("\n  A rule below the floor and not recovering is a delete-or-strengthen candidate")
        print("  (CLAUDE.md: 'Rule ignored 3 sessions -> delete or hook-ify').")
        print(f"  Inspect with: {sys.argv[0]} --examples <rule>")
    else:
        print("\nNo rule below the floor. Nothing to delete or strengthen.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
