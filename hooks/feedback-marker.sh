#!/usr/bin/env bash
# UserPromptSubmit hook — :) / :( feedback markers.
#
# Why: a bare emoticon prompt is a verdict on the PREVIOUS response. This hook
# makes that verdict do work: inject instructions to save a `feedback` memory
# (only when there is a reusable lesson) and log the verdict to
# ~/.claude/feedback.jsonl so the harvest/insights pipeline can track approval
# rate over time.
#
# Match is anchored: prompt must START with :) or :( (also :-) / :-( ), alone
# or followed by a short note, e.g. ":( too verbose". Emoticons mid-sentence
# never fire. Silent otherwise. Always exits 0.
#
# Kill switch: CLAUDE_SKIP_HOOKS=feedback-marker (comma-separated list).
set -uo pipefail

SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,feedback-marker,*) exit 0 ;; esac

input=$(cat 2>/dev/null || true)
prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null || true)
[ -z "$prompt" ] && exit 0

verdict="" note=""
if [[ "$prompt" =~ ^:-?\)[[:space:]]*(.*)$ ]]; then
  verdict="up" note="${BASH_REMATCH[1]}"
elif [[ "$prompt" =~ ^:-?\([[:space:]]*(.*)$ ]]; then
  verdict="down" note="${BASH_REMATCH[1]}"
fi
[ -z "$verdict" ] && exit 0

# Log for the insights pipeline. jq builds the JSON so the note is escaped safely.
session=$(printf '%s' "$input" | jq -r '.session_id // "unknown"' 2>/dev/null || echo unknown)
jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg s "$session" \
      --arg v "$verdict" --arg n "$note" --arg cwd "$PWD" \
      '{ts:$ts, session:$s, verdict:$v, note:$n, cwd:$cwd}' \
  >> "$HOME/.claude/feedback.jsonl" 2>/dev/null || true

if [ "$verdict" = "up" ]; then
  cat <<'EOF'
FEEDBACK MARKER :) — user approved your PREVIOUS response.
  • Identify what specifically worked (approach, format, depth — infer from the previous turn).
  • If there is a REUSABLE lesson: save/update a `feedback` memory (why + how to apply).
    Check for an existing memory covering the same topic first — update, don't duplicate.
  • Routine/trivial win: acknowledge in one short line, NO memory file.
  • Do not redo or extend the work. Logged to ~/.claude/feedback.jsonl already.
EOF
else
  cat <<'EOF'
FEEDBACK MARKER :( — user rejected your PREVIOUS response.
  • Root-cause what went wrong (wrong approach? too verbose? missed constraint? unverified claim?).
    Use the note after :( if present — it is the reason.
  • Cause unclear → ask ONE focused AskUserQuestion (2-4 options), do not guess.
  • Save the correction as a `feedback` memory (why + how to apply). Update existing
    memory on the same topic instead of duplicating.
  • Then fix the actual response if fixable now. Logged to ~/.claude/feedback.jsonl already.
EOF
fi

exit 0
