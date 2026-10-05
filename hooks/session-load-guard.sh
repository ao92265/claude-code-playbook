#!/usr/bin/env bash
# Session load guard — fires at SessionStart, the moment a new session is added.
#
# Reads the live board (~/.claude/sessions/<pid>.json, maintained by Claude Code)
# via sessions-board.sh. Warns when the count exceeds the working limit or when
# any session has blown the 4h cap from core-rules.md. Reports only — never
# kills a PID.
#
# Rationale: prose rules cannot fix overwhelm caused by session count. Eight
# concurrent panes at 95%+ context produce eight walls of text no matter how
# well shaped each one is. This is the guard for the actual cause.
#
# Tunable: MAX_SESSIONS below.
# Disable: remove the session-load-guard.sh entry from ~/.claude/settings.json,
#          or set CLAUDE_SKIP_HOOKS to include session-load-guard.

cat >/dev/null 2>&1

SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,session-load-guard,*) exit 0 ;; esac

MAX_SESSIONS=3
BOARD="$HOME/.claude/scripts/sessions-board.sh"
[ -x "$BOARD" ] || [ -f "$BOARD" ] || exit 0

out=$(bash "$BOARD" 2>/dev/null) || exit 0

live=$(printf '%s\n' "$out" | sed -n 's/^\([0-9]\{1,\}\) live Claude sessions.*/\1/p' | head -1)
[ -n "$live" ] || exit 0

# Session rows flagged with the >4h idle marker. The board also prints a legend
# line starting with ⚠ — exclude it or the count reads one too high.
stale_rows=$(printf '%s\n' "$out" | grep '⚠' | grep -v '^⚠')
stale=$(printf '%s' "$stale_rows" | grep -c . )

[ "$live" -le "$MAX_SESSIONS" ] && [ "$stale" -eq 0 ] && exit 0

echo "SESSION LOAD: ${live} live Claude sessions (working limit ${MAX_SESSIONS})."
if [ "$stale" -gt 0 ]; then
  echo "${stale} past the 4h cap:"
  printf '%s\n' "$stale_rows" | sed 's/^/  /'
fi
echo "HOLD THIS until the user actually starts work in this session: a build, a fix, a run, a review, any multi-step task. If his prompt is a question, a lookup, a chat turn or a one-liner, stay silent about sessions entirely and just answer him. Bolting this onto a trivia answer is the overload it exists to prevent. When real work does start, say it once at the top of that reply: the count, and the stale ones as close/reboot candidates (/reboot then close the tab). Then never again this session. Do not kill any session yourself."
