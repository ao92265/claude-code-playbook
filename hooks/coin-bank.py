#!/usr/bin/env python3
"""Atomic read/modify/write helper for the coin-rain state file."""
import fcntl
import json
import os
import sys

STATE_PATH = os.path.expanduser("~/.claude/hooks/coin-state.json")


DEFAULTS = {"total": 0, "last_earned": 0, "last_ts": 0, "last_fed_in": 0, "total_fed_in": 0}


def _load(f):
    f.seek(0)
    raw = f.read()
    if not raw.strip():
        return dict(DEFAULTS)
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return dict(DEFAULTS)


def earn(amount, ts, fed_in):
    """amount = coins paid out (completion tokens), fed_in = tokens spent (prompt, incl. cache)."""
    os.makedirs(os.path.dirname(STATE_PATH), exist_ok=True)
    fd = os.open(STATE_PATH, os.O_RDWR | os.O_CREAT, 0o644)
    with os.fdopen(fd, "r+") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        state = _load(f)
        state["total"] = state.get("total", 0) + amount
        state["last_earned"] = amount
        state["last_ts"] = ts
        state["last_fed_in"] = fed_in
        state["total_fed_in"] = state.get("total_fed_in", 0) + fed_in
        f.seek(0)
        f.truncate()
        json.dump(state, f)
    return state


if __name__ == "__main__":
    import time
    amt = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    fed_in = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    result = earn(amt, time.time(), fed_in)
    print(json.dumps(result))
