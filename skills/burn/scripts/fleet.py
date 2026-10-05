#!/usr/bin/env python3
"""Which session is actually eating the quota.

The percentages Claude Code reports are account wide. They say the account is
at 84% and nothing at all about which of six live sessions spent it, which is
the only question worth asking when six are running.

Nothing in the payload answers that, so the split comes from the transcripts:
every assistant message records its own token usage, and the transcript file is
the session. Subagent turns land in the same file as the session that spawned
them, so they are attributed there, which is right: it is that session's spend.

The split is by weighted tokens, not raw ones. A session re-reading a large
cached prompt racks up millions of raw tokens for almost nothing, and would
otherwise sit at the top of the list looking like the culprit while the session
generating real output sits below it.

What this is NOT: a second opinion on the percentage. Anthropic does not
publish how the quota weights models or cache tiers, so this is a share of
spend, not a share of quota, and it is labelled as an estimate everywhere it
is shown.
"""
from __future__ import annotations

import argparse
import calendar
import json
import os
import sys
import time

HOUR = 3600.0
WINDOW = 30 * 60          # same "right now" window the rate uses

# Relative to base input tokens. These are the published price ratios, which
# are stable across the model families here, not quota weights: nobody outside
# Anthropic has those. Check the claude-api skill if they ever move.
W_INPUT = 1.0
W_OUTPUT = 5.0
W_CACHE_READ = 0.1
W_CACHE_WRITE_5M = 1.25
W_CACHE_WRITE_1H = 2.0

CONFIG_DIR = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")

# Files older than the window cannot contain work inside it. An hour of slack
# covers a clock that disagrees with the timestamps in the file.
MTIME_GRACE = HOUR
TAIL_BYTES = 4 * 1024 * 1024


def _epoch(stamp):
    """Transcript timestamps are UTC. Parsing them through local time shifts
    every reading by the daylight saving offset and quietly empties the fleet
    for half the year."""
    if not isinstance(stamp, str):
        return None
    try:
        return calendar.timegm(time.strptime(stamp[:19], "%Y-%m-%dT%H:%M:%S"))
    except (ValueError, OverflowError):
        return None


def _weigh(usage):
    """Weighted tokens for one assistant turn."""
    if not isinstance(usage, dict):
        return 0.0
    creation = usage.get("cache_creation")
    if isinstance(creation, dict):
        five = creation.get("ephemeral_5m_input_tokens") or 0
        hour = creation.get("ephemeral_1h_input_tokens") or 0
    else:
        # Older turns only report the total. The cheaper tier is the safer
        # assumption: it under-claims rather than inventing spend.
        five = usage.get("cache_creation_input_tokens") or 0
        hour = 0
    return (
        (usage.get("input_tokens") or 0) * W_INPUT
        + (usage.get("output_tokens") or 0) * W_OUTPUT
        + (usage.get("cache_read_input_tokens") or 0) * W_CACHE_READ
        + five * W_CACHE_WRITE_5M
        + hour * W_CACHE_WRITE_1H
    )


def _raw(usage):
    if not isinstance(usage, dict):
        return 0
    return int((usage.get("input_tokens") or 0) + (usage.get("output_tokens") or 0))


def _read_tail(path, size):
    try:
        with open(path, "rb") as fh:
            if size > TAIL_BYTES:
                fh.seek(size - TAIL_BYTES)
                fh.readline()                 # drop the partial first line
            return fh.read().decode("utf-8", "ignore")
    except OSError:
        return ""


def scan(now, root=None, window=WINDOW):
    """One entry per transcript that did work inside the window."""
    root = root or os.path.join(CONFIG_DIR, "projects")
    cutoff = now - window
    out = []
    if not os.path.isdir(root):
        return out
    for dirpath, _dirs, files in os.walk(root):
        for name in files:
            if not name.endswith(".jsonl"):
                continue
            path = os.path.join(dirpath, name)
            try:
                st = os.stat(path)
            except OSError:
                continue
            if st.st_mtime < cutoff - MTIME_GRACE:
                continue
            entry = _scan_one(path, st.st_size, cutoff, name[:-6])
            if entry:
                out.append(entry)
    return out


def _scan_one(path, size, cutoff, stem):
    weighted = 0.0
    sub = 0.0
    raw = 0
    turns = 0
    last_ts = 0.0
    label = {}
    fallback = {}
    sid = None
    for line in _read_tail(path, size).splitlines():
        if '"usage"' not in line:
            continue
        try:
            row = json.loads(line)
        except ValueError:
            continue                          # a torn append, not a reason to stop
        if not isinstance(row, dict):
            continue
        ts = _epoch(row.get("timestamp"))
        if ts is None or ts < cutoff:
            continue
        msg = row.get("message") or {}
        w = _weigh(msg.get("usage"))
        weighted += w
        raw += _raw(msg.get("usage"))
        turns += 1
        this = {
            "slug": row.get("slug"),
            "cwd": row.get("cwd"),
            "branch": row.get("gitBranch"),
            "model": msg.get("model"),
            "effort": row.get("effort"),
        }
        fallback = this
        if row.get("isSidechain"):
            sub += w
        else:
            # Label from the session's own turns: a subagent runs on its own
            # model and effort and must not be mistaken for the session's.
            label = this
        sid = row.get("sessionId") or row.get("session_id") or sid
        last_ts = max(last_ts, ts)
    if weighted <= 0:
        return None
    entry = {
        "session_id": sid or stem,
        "path": path,
        "weighted": weighted,
        "subagent_weighted": sub,
        "raw_tokens": raw,
        "turns": turns,
        "last_ts": last_ts,
    }
    # A window where only subagents ran leaves no turn of his own to read the
    # labels off, so fall back to the subagent's own line rather than "?".
    src = label or fallback
    for k in ("slug", "cwd", "branch", "model", "effort"):
        entry[k] = src.get(k)
    return entry


def merge(entries):
    """One row per session, not per file.

    A subagent writes its own transcript carrying the session id of whatever
    spawned it, so a session that delegates heavily is spread over several
    files. Counted per file it appears three times and every row looks small,
    which is exactly backwards: it is the biggest spender in the list.
    """
    by = {}
    best = {}
    order = []
    for e in entries:
        sid = e["session_id"]
        # The label comes from the single file with the most of his own work in
        # it. Compared against the running TOTAL instead, two small files
        # outweigh the real one and the session ends up named after a
        # subagent.
        own = e["weighted"] - e["subagent_weighted"]
        if sid not in by:
            by[sid] = dict(e)
            by[sid]["paths"] = [e["path"]]
            best[sid] = own
            order.append(sid)
            continue
        cur = by[sid]
        for k in ("weighted", "subagent_weighted", "raw_tokens", "turns"):
            cur[k] += e[k]
        cur["last_ts"] = max(cur["last_ts"], e["last_ts"])
        cur["paths"].append(e["path"])
        if own > best[sid]:
            best[sid] = own
            for k in ("slug", "cwd", "branch", "model", "effort", "path"):
                cur[k] = e[k]
    return [by[sid] for sid in order]


def build(now=None, root=None, rate=None, window=WINDOW, session_id=None):
    now = now if now is not None else time.time()
    rows = merge(scan(now, root, window))
    total = sum(r["weighted"] for r in rows)
    rows.sort(key=lambda r: r["weighted"], reverse=True)
    for r in rows:
        r["share"] = (r["weighted"] / total) if total else 0.0
        r["subagent_share"] = (r["subagent_weighted"] / r["weighted"]) if r["weighted"] else 0.0
        r["is_current"] = bool(session_id) and r["session_id"] == session_id
        r["pct_per_h"] = (r["share"] * rate) if rate is not None else None
    return {
        "generated_at": now,
        "window_s": window,
        "total_weighted": total,
        "rate_now": rate,
        "sessions": rows,
    }


def _short(path, width=22):
    """Keep the identifying end of a path, not the front of it."""
    if not path:
        return "?"
    home = os.path.expanduser("~")
    if path.startswith(home):
        path = "~" + path[len(home):]
    if len(path) <= width:
        return path
    parts = path.split(os.sep)
    out = parts[-1]
    for part in reversed(parts[:-1]):
        nxt = part + os.sep + out
        if len(nxt) + 2 > width:
            break
        out = nxt
    return "…/" + out


def _clip(text, width):
    return text if len(text) <= width else text[:width - 1] + "…"


def _family(model):
    for fam in ("opus", "sonnet", "haiku"):
        if model and fam in model:
            return fam
    return model or "?"


def human(f):
    rows = f["sessions"]
    if not rows:
        return "No session has burned anything in the last %d minutes." % (f["window_s"] // 60)
    mins = f["window_s"] // 60
    # A rate of zero is what a freshly reset window reads for its first few
    # minutes. Printing it against every session says "nobody is doing
    # anything" while six sessions are hard at work, so the column goes.
    rate = f["rate_now"] or 0
    head = "%d session%s active in the last %dm" % (
        len(rows), "" if len(rows) == 1 else "s", mins)
    if rate:
        head += ", %.1f%%/h between them" % rate
    lines = [head + " (share of spend, estimated):"]
    for r in rows:
        bits = ["  %3.0f%%" % (r["share"] * 100)]
        if rate and r["pct_per_h"] is not None:
            bits.append("%5.1f%%/h" % r["pct_per_h"])
        bits.append("%-22s" % _clip(r["slug"] or r["session_id"][:8], 22))
        bits.append("%-22s" % _short(r["cwd"]))
        bits.append("%-6s" % _family(r["model"]))
        if r["subagent_share"] > 0.05:
            bits.append("%.0f%% subagents" % (r["subagent_share"] * 100))
        if r["is_current"]:
            bits.append("<- this session")
        lines.append(" ".join(bits).rstrip())
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--root", default=None)
    ap.add_argument("--now", type=float, default=None)
    ap.add_argument("--rate", type=float, default=None,
                    help="account %%/h to split across sessions")
    ap.add_argument("--window", type=int, default=WINDOW)
    ap.add_argument("--session", default=os.environ.get("CLAUDE_SESSION_ID"))
    args = ap.parse_args()
    f = build(args.now, args.root, args.rate, args.window, args.session)
    if args.json:
        json.dump(f, sys.stdout)
        sys.stdout.write("\n")
    else:
        print(human(f))
    return 0


if __name__ == "__main__":
    sys.exit(main())
