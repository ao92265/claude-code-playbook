#!/usr/bin/env bash
# ui-state-gate.sh - PreToolUse(Edit|Write). The blocking half of the UI state gate.
#
# Why here and not at the verdict: the expensive failure is not saying "that
# looks wrong", it is then FIXING the wrong thing. The align-dark saga spent
# roughly 15 commits chasing a parity gap that was a measurement error, because
# the screen was being judged under the wrong active theme. Blocking the first
# EDIT of an armed visual-QA session is the cheapest point that stops the bleed:
# reading, screenshotting and investigating stay completely free.
#
# Armed by ui-state-nudge.sh when the incoming prompt is visual-QA shaped.
# Satisfied by ui-state-recorder.sh when a real state query returns a real answer.
# Not armed means not applicable, so this is silent on every other session.
#
# Fires exactly once per session, on the block path as well as the pass path,
# because re-blocking every edit would make a themed refactor unworkable and
# there is no per-Edit escape hatch to offer.
#
# Exit codes: 0 allow, 2 block (Claude Code hook-denial convention)
# Disable: CLAUDE_SKIP_HOOKS=ui-state
SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,ui-state,*) exit 0 ;; esac
command -v jq >/dev/null 2>&1 || exit 0

set -uo pipefail
INPUT=$(cat 2>/dev/null || true)
printf '%s' "$INPUT" | jq -e . >/dev/null 2>&1 || exit 0

SID=$(printf '%s' "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null || true)
SID=$(printf '%s' "$SID" | tr -dc 'A-Za-z0-9_-'); SID=${SID:-default}

STATE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/state/ui-state"
ARMED="$STATE_DIR/armed-${SID}"
ASSERTED="$STATE_DIR/asserted-${SID}"
PASSED="$STATE_DIR/passed-${SID}"

# Not a visual-QA session, or already let through once. Nothing to do.
[ -f "$ARMED" ] || exit 0
[ -f "$PASSED" ] && exit 0

# The state was actually read this session. Let it through and stop checking.
if [ -f "$ASSERTED" ]; then
  : > "$PASSED" 2>/dev/null || true
  exit 0
fi

# Editing the styles themselves is the case worth catching. Editing a test, a
# doc or a hook during a visual-QA session is not what burned the sessions, and
# blocking it would just teach you to disable the hook.
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
case "$FILE" in
  *.css|*.scss|*.sass|*.less|*.styl) ;;
  *.tsx|*.jsx|*.vue|*.svelte|*.html) ;;
  *tailwind*|*theme*|*Theme*|*tokens*|*.style.ts|*.styles.ts) ;;
  *) exit 0 ;;
esac
case "$FILE" in
  *.test.*|*.spec.*|*/tests/*|*/__tests__*|*.md) exit 0 ;;
esac

WHY=$(cat "$ARMED" 2>/dev/null | head -1 || true)
# Block once and then stand down. The point is to interrupt before the first
# fix goes into an unverified screen state, not to hold the session hostage:
# the escape printed below cannot work for an Edit call (no command line to
# prefix, and firewall.sh already documents that a prefixed variable never
# reaches a hook), so without this the only way out was to disable the hook.
: > "$PASSED" 2>/dev/null || true
cat >&2 <<MSG
[ui-state-gate] BLOCKED. Visual-QA session, live state never asserted.

About to edit: $FILE
Armed because the prompt looked like visual QA: ${WHY:-theme/parity/comparison}

No query this session has actually READ the active theme, variant or flag. The
align-dark work lost multiple sessions and roughly 15 commits to exactly this:
a parity gap that turned out to be a verdict rendered under the wrong theme. The
fix went into the wrong screen state, so it could never converge.

Read the live state first, then this unblocks for the rest of the session:

  javascript_tool: ({
    theme: document.documentElement.getAttribute('data-theme'),
    classes: document.documentElement.className,
    prefers: matchMedia('(prefers-color-scheme: dark)').matches,
    bg: getComputedStyle(document.body).backgroundColor
  })

Confirm the value matches the design you are comparing against BEFORE you edit.
If it does not, you are looking at the wrong screen, not a bug.

This gate has now stood down for the rest of the session, so the retry goes
through either way. It fires once so it cannot become noise. If you retry
without reading the state, you are choosing to fix a screen you have not
identified, which is the thing that cost align-dark its sessions.
MSG
exit 2
