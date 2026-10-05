#!/usr/bin/env python3
"""Latch "tldr" for the rest of the session.

Registered from the tldr skill's frontmatter (`hooks:` with `once: true`), so it
fires exactly once, at the end of the turn where the user asked for a tldr.

Why this exists: "tldr" is a register correction, not a one-off ask (see the
tldr-means-stay-short memory). Before this, staying short for the rest of the
session depended on the model remembering, which decays as context grows. This
writes a marker instead, and register-gate.py reads it and tightens its length
ceiling for every later reply in the same session.

Never blocks. A failure here must not cost the user a turn, so every error path exits 0.
"""

import json
import os
import sys
import time
from pathlib import Path

STATE = Path.home() / ".claude" / "state" / "register-gate"
MAX_AGE_DAYS = 7


def sweep() -> None:
    """Drop markers from sessions that ended a week ago. Cheap, best effort.

    Covers every marker kind the gate writes, not just this one. The `.last` files were
    accumulating with nothing to clear them, and a stale one means a reply whose text
    exactly repeats an old blocked reply slips through unchecked. Found in review,
    21 Aug 2026.
    """
    cutoff = time.time() - MAX_AGE_DAYS * 86400
    for pattern in ("*.tldr", "*.last", "*.streak"):
        try:
            for f in STATE.glob(pattern):
                if f.stat().st_mtime < cutoff:
                    f.unlink()
        except OSError:
            pass


def main() -> None:
    if "tldr-mode" in os.environ.get("CLAUDE_SKIP_HOOKS", ""):
        sys.exit(0)
    try:
        payload = json.loads(sys.stdin.read() or "{}")
    except (ValueError, TypeError):
        sys.exit(0)

    session = str(payload.get("session_id") or "").strip()
    if not session:
        sys.exit(0)

    try:
        STATE.mkdir(parents=True, exist_ok=True)
        # Same shape as a transcript timestamp (ISO 8601, UTC, trailing Z), because
        # register-gate compares this against entry timestamps as plain strings to
        # decide whether a later /clear has ended the latch.
        stamp = time.strftime("%Y-%m-%dT%H:%M:%S.000Z", time.gmtime())
        (STATE / f"{session}.tldr").write_text(stamp)
    except OSError:
        pass

    sweep()
    sys.exit(0)


if __name__ == "__main__":
    main()
