#!/usr/bin/env bash
# correction-detect.sh -- UserPromptSubmit hook. Catches corrections phrased in
# plain English, so a lesson gets captured without anyone typing a marker.
#
# Why: feedback-marker.sh (the :) / :( hook) has been live since 2026-07-22 and
# has exactly one real entry in feedback.jsonl. The other two are smoke tests.
# Markers depend on remembering to type them, and the evidence says that does
# not happen. Meanwhile the corrections themselves are constant and obvious in
# the transcripts. Every tier-1 and tier-2 pattern below is lifted from real
# friction text in ~/.claude/skills/myinsights/data/local-facets/*.json:
#   "tldr i dont understand" / "make it more layman terms plz"
#   "what? just answer her question" / "nah didnt work"
#   "none of this sounds like what id right" / "dont make the message so long"
#
# :( stays as the manual override for phrasings no pattern catches.
#
# Two tiers, both tuned for near-zero false positives:
#   tier 1 -- prompt-INITIAL markers. Anchored, same discipline as
#             feedback-marker.sh. A prompt that opens with "no," is a correction.
#   tier 2 -- markers anywhere, but only in a SHORT prompt (<= 140 chars). A long
#             prompt containing "too long" is usually describing something; a
#             30-character prompt saying "too long" is a verdict.
#
# Always exits 0. This nudges, it never blocks.
#
# Disable: CLAUDE_SKIP_HOOKS=correction-detect
set -uo pipefail

SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,correction-detect,*) exit 0 ;; esac

input=$(cat 2>/dev/null || true)
command -v jq >/dev/null 2>&1 || exit 0
prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null || true)
[ -z "$prompt" ] && exit 0

# :) / :( are feedback-marker.sh's job. Never double-fire.
case "$prompt" in ":)"*|":("*|":-)"*|":-("*) exit 0 ;; esac

p=$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')
len=${#prompt}
matched=""

# --- tier 1a: prompt-initial, unambiguous at any length ---------------------
# These cannot plausibly open a normal work request.
case "$p" in
  "no,"*|"no."*|nope*|nah*)                         matched="opening negation" ;;
  wrong*|"thats not"*|"that's not"*|"thats wrong"*|"that's wrong"*)
                                                    matched="direct contradiction" ;;
  tldr*|"none of this"*)                            matched="wholesale rejection" ;;
  "you didnt"*|"you didn't"*|"you missed"*)         matched="pointing at what was skipped" ;;
esac

# --- tier 1b: prompt-initial, but only when terse ---------------------------
# "i said", "not", "dont" and friends legitimately OPEN a long narrative prompt
# ("I said earlier I would review this, and now I want to..."). At correction
# length they are verdicts; at essay length they are context. Ceiling matches
# tier 2. Real corrections in the facet corpus all sit under 80 characters.
if [ -z "$matched" ] && [ "$len" -le 140 ]; then
  case "$p" in
    "no "*|"not "*)                                 matched="opening negation" ;;
    "i said"*|"i meant"*|"i asked"*|"i wanted"*)    matched="restating the original ask" ;;
    "you dont"*|"you don't"*)                       matched="pointing at what was skipped" ;;
    "dont "*|"don't "*|"stop "*)                    matched="told to stop doing something" ;;
    "why did you"*|"why are you"*|"what?"*)         matched="challenge to the approach" ;;
  esac
fi

# --- tier 2: anywhere, short prompts only -----------------------------------
if [ -z "$matched" ] && [ "$len" -le 140 ]; then
  case "$p" in
    *layman*|*"plain english"*|*"dont understand"*|*"don't understand"*)
                                                    matched="register too technical" ;;
    *"too verbose"*|*"too long"*|*"too technical"*|*"too complex"*|*"too much"*|*"so long"*)
                                                    matched="response too heavy" ;;
    *"not what i"*|*"just answer"*|*"answer the question"*)
                                                    matched="answered the wrong thing" ;;
    *"didnt work"*|*"didn't work"*|*"doesnt work"*|*"doesn't work"*|*"still broken"*|*"still failing"*)
                                                    matched="claimed working, was not" ;;
    *"ai slop"*|*"sounds like ai"*|*"em dash"*)     matched="prose tells" ;;
  esac
fi

[ -z "$matched" ] && exit 0

# Log alongside the manual markers so one consumer covers both channels.
session=$(printf '%s' "$input" | jq -r '.session_id // "unknown"' 2>/dev/null || echo unknown)
jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg s "$session" \
      --arg n "$matched" --arg cwd "$PWD" \
      '{ts:$ts, session:$s, verdict:"down", note:$n, source:"auto", cwd:$cwd}' \
  >> "$HOME/.claude/feedback.jsonl" 2>/dev/null || true

cat <<EOF
CORRECTION DETECTED ($matched). This prompt reads as a verdict on your PREVIOUS response.
  • Root-cause it before you act. Wrong approach? Too verbose? Missed constraint? Unverified claim?
    Name the cause to yourself; do not just comply and move on.
  • If the same cause could bite again, save or UPDATE a \`feedback\` memory (why + how to apply).
    Check for an existing memory on the topic first. Update, never duplicate.
  • One-off with no reusable lesson: skip the memory, just fix it.
  • Do not apologise or narrate the correction. Fix the response.
  • Pattern-matched, so it may be a false positive. If this prompt is not a correction, ignore this block silently.
EOF

# Register complaints have one specific fix, so name it rather than leaving the
# generic "root-cause it" advice to be interpreted. The tldr skill is now
# model-invocable (disable-model-invocation removed 2026-08-10), so this is
# reachable without him typing the slash command.
case "$matched" in
  "register too technical"|"response too heavy")
    cat <<'EOF'
  • FIX SHAPE (this match has one): invoke the `tldr` skill on your last reply. Detail goes to
    a file, the transcript gets what changed / what he decides / what's next, plus the path.
    Do not re-send the same content with fewer words: cut the jargon, not just the length.
EOF
    ;;
esac

exit 0
