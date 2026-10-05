#!/usr/bin/env python3
"""Usage momentum and breach projection for the 5 hour and 7 day windows.

Reads the percentage history recorded by the HUD and answers one question:
at the rate you are going, do you run out before the window resets.

The numbers come from Claude Code's own statusline payload
(rate_limits.five_hour / rate_limits.seven_day), which is Anthropic's server
side accounting. Nothing here reconstructs a quota from token counts, because
the weighting across models and cache tiers is not published and a made up
percentage is worse than no percentage.
"""
from __future__ import annotations

import argparse
import calendar
import json
import os
import statistics
import sys
import time

HOUR = 3600.0
DAY = 86400.0

# How far back "right now" reaches. Half an hour is long enough to survive a
# quiet minute between prompts and short enough to notice a heavy run starting.
NOW_WINDOW = 30 * 60

# The percentages arrive as whole numbers, so any measured change carries about
# a point of rounding with it. Over four minutes a single step from 94 to 95
# reads as 15%/h and the truth is anywhere from nothing to twice that. Breach
# is therefore decided on the conservative end of that band: the rate you can
# still justify after handing back the rounding. The reported rate stays the
# straight reading, because that is the honest best guess to show.
QUANTISATION = 1.0

# How much wall clock a rate needs under it before it is allowed to block a
# prompt. Below this a single rounding step reads as a triple digit rate, which
# is how twenty one seconds of cross session snapshot jitter once blocked a
# prompt at 35% of the window. Thin readings are still reported, they just stop
# being grounds for a block.
MIN_DECIDE_SPAN = 5 * 60

# The baseline is a flat 24 hour average, idle time included. That is the
# honest denominator for "is this hour heavier than normal": excluding idle
# hours would make every working hour look average.
BASELINE_WINDOW = DAY

CONFIG_DIR = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")
DEFAULT_HISTORY = os.path.join(CONFIG_DIR, "usage-history.jsonl")

WINDOWS = ("five_hour", "seven_day")

# Which rate drives the projection.
#   five_hour: the horizon is at most five hours, so what you are doing right
#     now is exactly the right predictor.
#   seven_day: the horizon is up to seven days. A busy half hour says nothing
#     about Thursday, so the 24 hour average drives it instead.
BASIS = {"five_hour": "current", "seven_day": "baseline"}

# The other half of the ladder. Stepping down is only half a policy: if
# nothing ever says "you can afford the big model again", one busy hour costs
# the rest of the day. Slack is how many times the current burn would fit into
# the burn that lands exactly at 100% when the window resets, so 5 means you
# could work five times harder and still not run out.
SCALE_UP_SLACK = 2.0

# Samples only land while a statusline is rendering, so gaps are normal. A
# reading this old is fine for saying what happened and useless for saying
# what is happening, and "go back up to the big model" is the one direction
# where being wrong costs a breach.
FRESH_S = 5 * 60

# How far past 100% the projection has to land before a window counts as
# breaching. The 5 hour horizon is short and the current rate predicts it well,
# so any crossing counts. The 7 day horizon is up to five days out and rests on
# a 24 hour average, where a projection of 108% is inside the error of the
# estimate. Interrupting on that is a false alarm, and a hook that raises false
# alarms gets switched off.
BREACH_AT = {"five_hour": 100.0, "seven_day": 115.0}

# An idle window has infinite slack, which is neither printable nor JSON. This
# is the "as much room as you could want" reading.
SLACK_CAP = 99.0


def load(path):
    """Read jsonl, skipping anything that will not parse.

    Six sessions append to this file, so a torn line is expected rather than
    exceptional. Same shape as the loader in the learn skill.
    """
    rows = []
    if not os.path.exists(path):
        return rows
    try:
        with open(path, encoding="utf-8", errors="ignore") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    row = json.loads(line)
                except ValueError:
                    continue
                if isinstance(row, dict) and isinstance(row.get("ts"), (int, float)):
                    rows.append(row)
    except OSError:
        return []
    rows.sort(key=lambda r: r["ts"])
    return rows


def series(rows, key):
    """Pull (ts, percentage, resets_at) for one window, newest last."""
    out = []
    for r in rows:
        w = r.get(key)
        if not isinstance(w, dict):
            continue
        pct = w.get("used_percentage")
        if not isinstance(pct, (int, float)):
            continue
        reset = w.get("resets_at")
        out.append((float(r["ts"]), float(pct),
                    float(reset) if isinstance(reset, (int, float)) else None))
    return out


def segment(points):
    """Split at every window reset.

    The 5 hour percentage collapses to near zero every five hours. A rate
    computed across that boundary reads as a large negative burn, which is why
    every rate below is confined to one segment. The reset is detected two
    ways: resets_at moving forward is definitive, and the percentage dropping
    is the fallback for samples that carry no reset time.
    """
    segs = []
    cur = []
    prev = None
    for p in points:
        if prev is not None:
            ts, pct, reset = p
            pts, ppct, preset = prev
            rolled = False
            if reset is not None and preset is not None:
                # Both samples carry a reset time, so it is the whole answer.
                # A percentage dropping while that time sits still is a stale
                # snapshot from another live session, not a window that rolled.
                rolled = reset > preset + 1
            elif pct < ppct - 0.5:
                rolled = True
            if rolled:
                segs.append(cur)
                cur = []
        cur.append(p)
        prev = p
    if cur:
        segs.append(cur)
    return [monotonic(s) for s in segs]


def monotonic(seg):
    """Flatten stale snapshots out of one window's series.

    Inside a single window the recorded percentage only ever climbs. Several
    live sessions write into one shared history though, and each carries a
    snapshot of a different age, so the merged series dips whenever an older
    one lands last. The freshest reading is the highest one, so carrying the
    running maximum forward removes the dips without touching the real climb.
    """
    out = []
    top = None
    for ts, pct, reset in seg:
        top = pct if top is None else max(top, pct)
        out.append((ts, top, reset))
    return out


def rate_between(a, b):
    """Percentage points per hour. Elapsed time is wall clock, never sample
    count, so an idle gap correctly dilutes the rate instead of vanishing."""
    hours = (b[0] - a[0]) / HOUR
    if hours <= 0:
        return None
    return (b[1] - a[1]) / hours


def current_rate(seg, now):
    """Points per hour over the last half hour of the live segment.

    Returns (rate, floor, thin, span). `floor` is the same rate with a point
    of rounding handed back, and it is what the breach decision uses. `thin`
    means the segment is younger than the window, so the reading is real but
    built on less evidence than it wants. `span` is the wall clock the reading
    actually rests on, which is what decides whether it may block a prompt.
    """
    if len(seg) < 2:
        return None, None, True, 0.0
    recent = [p for p in seg if p[0] >= now - NOW_WINDOW]
    if len(recent) < 2:
        recent = seg[-2:]
    span = recent[-1][0] - recent[0][0]
    rate = rate_between(recent[0], recent[-1])
    floor = None
    if rate is not None:
        hours = span / HOUR
        delta = recent[-1][1] - recent[0][1]
        floor = max(0.0, (delta - QUANTISATION) / hours) if hours > 0 else None
    return rate, floor, span < NOW_WINDOW - 1, float(span)


def baseline_rate(segs, now):
    """Points burned in the last 24 hours, divided by 24.

    Summed across segments, so several full 5 hour windows in a day add up
    past 100 rather than being clipped. A pair straddling the 24 hour edge is
    prorated by the fraction of it that falls inside.
    """
    cutoff = now - BASELINE_WINDOW
    total = 0.0
    seen = False
    for seg in segs:
        for a, b in zip(seg, seg[1:]):
            if b[0] <= cutoff:
                continue
            delta = b[1] - a[1]
            if delta <= 0:
                seen = True
                continue
            span = b[0] - a[0]
            if a[0] < cutoff and span > 0:
                delta *= (b[0] - cutoff) / span
            total += delta
            seen = True
    if not seen:
        return None
    return total / (BASELINE_WINDOW / HOUR)


def assess(rows, key, now, token_momentum=None):
    pts = series(rows, key)
    empty = {
        "used_percentage": None, "resets_at": None, "resets_in_s": None,
        "rate_now": None, "rate_floor": None, "rate_baseline": None,
        "momentum": None,
        "basis": BASIS[key], "basis_fallback": False, "rate_shown": None,
        "projected_at_reset": None, "will_breach": False,
        "seconds_to_100": None, "thin": True, "baseline_source": "none",
        "samples": 0, "ceiling_rate": None, "slack": None, "evidence_s": 0.0,
        "age_s": None,
    }
    if not pts:
        return empty

    segs = segment(pts)
    live = segs[-1]
    last = live[-1]
    pct_now, reset = last[1], last[2]

    rate_now, rate_floor, thin, now_span = current_rate(live, now)
    rate_base = baseline_rate(segs, now)

    span = pts[-1][0] - pts[0][0]
    if rate_base is not None and span >= BASELINE_WINDOW:
        source = "recorded"
        momentum = (rate_now / rate_base) if (rate_now is not None and rate_base) else None
    elif token_momentum is not None:
        # Day one: not enough recorded history for a 24 hour baseline, so the
        # ratio comes from transcript token burn instead. It is a ratio only.
        # Tokens cannot be turned into a percentage of the quota, so the
        # absolute projection below still comes from the recorded percentages.
        source = "transcripts"
        momentum = token_momentum
    else:
        source = "recorded" if rate_base is not None else "none"
        momentum = (rate_now / rate_base) if (rate_now is not None and rate_base) else None

    basis = BASIS[key]
    # What gets shown, and what the breach is decided on. They differ only by
    # the rounding band, and only the decision uses the cautious one.
    rate_shown = rate_now if basis == "current" else rate_base
    rate_decide = rate_floor if basis == "current" else rate_base
    fallback = False
    if rate_shown is None:
        rate_shown = rate_base if basis == "current" else rate_now
        rate_decide = rate_shown
        fallback = rate_shown is not None
    if rate_decide is None:
        rate_decide = rate_shown

    # A reading with only seconds of wall clock under it is real but it is not
    # evidence: one point of rounding over twenty seconds reads as hundreds of
    # points per hour. Keep showing it, but decide on the 24 hour baseline,
    # which is the only rate here measured over a real stretch of time. If
    # there is no baseline yet then nothing has earned the right to block.
    if basis == "current" and now_span < MIN_DECIDE_SPAN:
        rate_decide = rate_base

    resets_in = (reset - now) if reset else None
    projected = None
    breach = False
    to_100 = None
    if rate_shown is not None and resets_in is not None and resets_in > 0:
        projected = pct_now + rate_shown * (resets_in / HOUR)
        if rate_decide is not None:
            breach = (pct_now + rate_decide * (resets_in / HOUR)) > BREACH_AT.get(key, 100.0)
        if breach and rate_shown > 0 and pct_now < 100.0:
            to_100 = (100.0 - pct_now) / rate_shown * HOUR

    # How hard you could burn and still land exactly on 100% at the reset,
    # and how many times over your current burn that is.
    ceiling = None
    slack = None
    if resets_in is not None and resets_in > 0 and pct_now < 100.0:
        ceiling = (100.0 - pct_now) / (resets_in / HOUR)
        if rate_shown is not None:
            slack = SLACK_CAP if rate_shown <= 0 else min(SLACK_CAP, ceiling / rate_shown)

    return {
        "used_percentage": pct_now,
        "resets_at": reset,
        "resets_in_s": resets_in,
        "rate_now": rate_now,
        "rate_floor": rate_floor,
        "rate_baseline": rate_base,
        "momentum": momentum,
        "basis": basis,
        "rate_shown": rate_shown,
        "basis_fallback": fallback,
        "projected_at_reset": projected,
        "will_breach": breach,
        "seconds_to_100": to_100,
        "thin": thin,
        "baseline_source": source,
        "samples": len(pts),
        "ceiling_rate": ceiling,
        "slack": slack,
        "evidence_s": live[-1][0] - live[0][0],
        "age_s": now - last[0],
    }


# ---------------------------------------------------------------------------
# Day one fallback.
#
# The recorder needs 24 hours before it can say what a normal hour looks like.
# The transcripts already know: two months of them, every assistant message
# carrying its own token counts and a timestamp. They give a ratio (is this
# half hour heavier than the last day) and nothing more. They deliberately do
# NOT produce a percentage, because converting tokens to quota would mean
# inventing Anthropic's weighting.
# ---------------------------------------------------------------------------
TAIL_BYTES = 4 * 1024 * 1024
TOKEN_CACHE_TTL = 600


def _iso_to_epoch(s):
    try:
        t = time.strptime(s[:19], "%Y-%m-%dT%H:%M:%S")
    except ValueError:
        return None
    return calendar.timegm(t)


def _grab_int(line, field):
    i = line.find(field)
    if i < 0:
        return 0
    i = line.find(":", i + len(field))
    if i < 0:
        return 0
    j = i + 1
    while j < len(line) and line[j] == " ":
        j += 1
    k = j
    while k < len(line) and line[k].isdigit():
        k += 1
    return int(line[j:k]) if k > j else 0


def scan_transcripts(now, root=None):
    """Tokens per hour over the last 30 minutes and over the last 24 hours.

    Bounded on purpose: only files touched in the last 25 hours, and only the
    tail of each. A projection is not worth a three gigabyte read.
    """
    root = root or os.path.join(CONFIG_DIR, "projects")
    if not os.path.isdir(root):
        return None
    cutoff = now - BASELINE_WINDOW
    recent_cut = now - NOW_WINDOW
    recent = 0
    day = 0
    try:
        for dirpath, _dirs, files in os.walk(root):
            for name in files:
                if not name.endswith(".jsonl"):
                    continue
                path = os.path.join(dirpath, name)
                try:
                    st = os.stat(path)
                except OSError:
                    continue
                if st.st_mtime < cutoff - HOUR:
                    continue
                try:
                    with open(path, "rb") as fh:
                        if st.st_size > TAIL_BYTES:
                            fh.seek(st.st_size - TAIL_BYTES)
                            fh.readline()          # drop the partial line
                        blob = fh.read().decode("utf-8", "ignore")
                except OSError:
                    continue
                for line in blob.splitlines():
                    if '"usage"' not in line:
                        continue
                    i = line.find('"timestamp":"')
                    if i < 0:
                        continue
                    ts = _iso_to_epoch(line[i + 13:i + 33])
                    if ts is None or ts < cutoff:
                        continue
                    n = _grab_int(line, '"input_tokens"') + _grab_int(line, '"output_tokens"')
                    day += n
                    if ts >= recent_cut:
                        recent += n
    except OSError:
        return None
    if day <= 0:
        return None
    per_hour_day = day / (BASELINE_WINDOW / HOUR)
    per_hour_now = recent / (NOW_WINDOW / HOUR)
    if per_hour_day <= 0:
        return None
    return per_hour_now / per_hour_day


def cached_token_momentum(now):
    cache = os.path.join(CONFIG_DIR, "hud", "cache", "burn-tokens.json")
    try:
        st = os.stat(cache)
        if now - st.st_mtime < TOKEN_CACHE_TTL:
            with open(cache, encoding="utf-8") as fh:
                return json.load(fh).get("momentum")
    except (OSError, ValueError):
        pass
    value = scan_transcripts(now)
    try:
        os.makedirs(os.path.dirname(cache), exist_ok=True)
        tmp = cache + ".tmp.%d" % os.getpid()
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump({"momentum": value}, fh)
        os.replace(tmp, cache)
    except OSError:
        pass
    return value


def _fmt_dur(secs):
    if secs is None:
        return "?"
    secs = int(secs)
    if secs <= 0:
        return "now"
    d, rem = divmod(secs, 86400)
    h, rem = divmod(rem, 3600)
    m = rem // 60
    if d:
        return "%dd%dh" % (d, h)
    if h:
        return "%dh%02dm" % (h, m)
    return "%dm" % m


def _fmt_rate(v):
    return ("%.2f" if abs(v) < 1 else "%.1f") % v


def human(verdict):
    lines = []
    for key, label in (("five_hour", "5 hour"), ("seven_day", "7 day")):
        v = verdict[key]
        if v["used_percentage"] is None:
            lines.append("%s: no history yet." % label)
            continue
        lines.append("%s: %.0f%% used, resets in %s" % (
            label, v["used_percentage"], _fmt_dur(v["resets_in_s"])))

        if v["rate_now"] is not None:
            bit = "  burning %s%%/h now" % _fmt_rate(v["rate_now"])
            if v["baseline_source"] == "recorded" and v["rate_baseline"] is not None:
                bit += ", %s%%/h is normal" % _fmt_rate(v["rate_baseline"])
                if v["momentum"] is not None:
                    bit += " (%.1fx normal)" % v["momentum"]
            elif v["baseline_source"] == "transcripts" and v["momentum"] is not None:
                # The recorded baseline is meaningless this early, so it is not
                # shown at all. Printing a number from one source under a label
                # from another is how a reading gets trusted that should not be.
                bit += ", %.1fx your last 24h (estimated from transcripts)" % v["momentum"]
            else:
                bit += ", no baseline yet"
            if v["thin"]:
                bit += " [thin]"
            lines.append(bit)

        proj = v["projected_at_reset"]
        if v["will_breach"]:
            lines.append("  OVER in %s, projected %.0f%% at reset"
                         % (_fmt_dur(v["seconds_to_100"]), proj))
        elif proj is not None and proj > 100:
            # The straight reading crosses the line but the cautious one does
            # not, which means the evidence is inside its own rounding. Say
            # that, rather than showing 107% next to a clean bill of health.
            lines.append("  maybe: best guess %.0f%% at reset, too thin to call"
                         % proj)
        elif proj is not None:
            # Name the rate that drove it. The weekly window projects on the
            # 24 hour average, so "burning 0%/h now" next to "40% at reset"
            # otherwise reads as a contradiction rather than a design choice.
            how = "at your current rate" if v["basis"] == "current" \
                else "at your 24h average"
            lines.append("  on track for %.0f%% at reset (%s)" % (proj, how))

        # The way back up. Only worth saying where there is real room: at 1.5x
        # spare it is noise, and at four hours of headroom it is the reason he
        # is on the small model for no reason.
        if verdict.get("can_scale_up") and v["slack"] and key == "five_hour":
            lines.append("  room to spare: about %.0fx your current burn"
                         % min(v["slack"], verdict["slack"] or v["slack"]))

    f = verdict.get("fleet")
    if f:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        try:
            import fleet as _fleet
            lines.append("")
            lines.append(_fleet.human(f))
        except ImportError:
            pass
    return "\n".join(lines)


def load_fleet(now, verdict, root=None, session_id=None):
    """Split the account rate across the sessions that are actually running.

    Imported lazily and only when asked: the throttle runs on every prompt and
    must not walk the transcript tree to decide whether to say nothing.
    """
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    try:
        import fleet as _fleet
    except ImportError:
        return None
    rate = verdict["five_hour"]["rate_now"]
    return _fleet.build(now, root=root, rate=rate, session_id=session_id)


def build(history=None, now=None, use_transcripts=True,
          want_fleet=False, projects=None, session_id=None):
    now = now if now is not None else time.time()
    rows = load(history or DEFAULT_HISTORY)
    tok = None
    if use_transcripts:
        span = (rows[-1]["ts"] - rows[0]["ts"]) if len(rows) > 1 else 0
        if span < 2 * BASELINE_WINDOW:
            tok = cached_token_momentum(now)
    verdict = {k: assess(rows, k, now, tok) for k in WINDOWS}
    breaching = [k for k in WINDOWS if verdict[k]["will_breach"]]
    verdict["worst"] = breaching[0] if breaching else None

    # Only windows that actually have a reading get a vote, and one tight
    # window vetoes the rest: the weekly cap is the one that quietly runs out
    # while every five hour window looks fine.
    voting = [verdict[k] for k in WINDOWS if verdict[k]["slack"] is not None]
    # Evidence, not the thin flag: with one sample a minute the last half hour
    # is always a hair under half an hour, so thin flickers. What matters here
    # is that the window has been watched for at least that long.
    verdict["can_scale_up"] = bool(voting) and not breaching and all(
        v["slack"] >= SCALE_UP_SLACK and v["evidence_s"] >= NOW_WINDOW
        and v["age_s"] is not None and v["age_s"] <= FRESH_S
        for v in voting)
    verdict["slack"] = min([v["slack"] for v in voting]) if voting else None
    verdict["generated_at"] = now
    verdict["fleet"] = (load_fleet(now, verdict, projects, session_id)
                        if want_fleet else None)
    return verdict


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--json", action="store_true", help="machine readable output")
    ap.add_argument("--history", default=None)
    ap.add_argument("--now", type=float, default=None)
    ap.add_argument("--no-transcripts", action="store_true",
                    help="skip the day one transcript baseline")
    ap.add_argument("--fleet", action="store_true",
                    help="split the burn across the live sessions")
    ap.add_argument("--projects", default=None,
                    help="transcript root (defaults to the real one)")
    ap.add_argument("--session", default=os.environ.get("CLAUDE_SESSION_ID"))
    args = ap.parse_args()
    verdict = build(args.history, args.now, not args.no_transcripts,
                    args.fleet, args.projects, args.session)
    if args.json:
        json.dump(verdict, sys.stdout)
        sys.stdout.write("\n")
    else:
        print(human(verdict))
    return 0


if __name__ == "__main__":
    sys.exit(main())
