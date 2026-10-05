#!/usr/bin/env bash
# ui-state-nudge.sh — UserPromptSubmit hook.
#
# Why: recurring theme-parity FALSE verdicts (myinsights 2026-07-24). The
# align-dark saga stalled repeatedly because UI parity was judged under the
# WRONG active theme/state — a "wrong-looking" call that was actually a
# measurement error, costing whole sessions. When the incoming prompt is a
# visual-QA / theme / parity task, re-inject the assert-state-first rule right
# next to the request so it binds (same precedent as factual-guardrail-nudge).
#
# Non-blocking: a hook can't observe the DOM, so it only NUDGES. Silent on
# non-visual prompts. Always exit 0.
#
# Disable: CLAUDE_SKIP_HOOKS=ui-state-nudge
SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,ui-state-nudge,*) exit 0 ;; esac
command -v jq >/dev/null 2>&1 || exit 0

set -uo pipefail
INPUT=$(cat 2>/dev/null || true)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)
[ -z "$PROMPT" ] && exit 0
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null || true)
SID=$(printf '%s' "$SID" | tr -dc 'A-Za-z0-9_-'); SID=${SID:-default}

# Visual-QA / theme / parity / state-comparison intent. Case-insensitive.
# Comparison intent only. A bare noun ('theme', 'toggle', 'feature flag') used to
# match, which armed a BLOCKING gate on prompts like "the sidebar toggle is
# broken, fix it" and then blocked every component edit in the session. The
# nudge and the gate share this pattern, so it has to earn a block, not a hint.
pattern='dark ?mode|light ?mode|data-theme|parity|pixel ?diff|visual (qa|diff|verdict|regression)|looks? (wrong|off|broken|different)|does(n.?t| not)?[^.]{0,25}match|match(es)? the (mock|design|reference|screenshot)|compare (the )?(screenshot|design|mock|reference|theme|two)|(theme|variant|flag) (parity|switch(er)?|pass|sweep|toggle)|(check|verify|compare|review|qa|audit|sweep) [^.]{0,30}(theme|dark|light|variant)|(theme|dark|light) [^.]{0,20}(parity|pass|sweep|audit|regression)|like.for.like|side.by.side'

if printf '%s' "$PROMPT" | grep -qiE "$pattern"; then
  # Arm the blocking half. The nudge below can be read and ignored, which is
  # exactly what happened to align-dark; ui-state-gate.sh is what actually stops
  # an edit going into an unverified screen state.
  _sd="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/state/ui-state"
  mkdir -p "$_sd" 2>/dev/null || true
  printf '%s\n' "$(printf '%s' "$PROMPT" | tr -d '\n' | cut -c1-160)" > "$_sd/armed-${SID}" 2>/dev/null || true
  echo "<system-reminder>UI-QA (design-rules): ASSERT THE ACTIVE STATE FIRST. Log the real \`data-theme\`/active variant/feature-flag state and confirm it matches the design you're comparing against BEFORE calling parity or a bug — a verdict under the wrong theme is a false negative (align-dark stalled on exactly this). Then use visual-verdict (judge images) + demo-qa (drive + root-cause in source). Never self-certify from your own screenshots, have the user confirm in his real browser. This is now ENFORCED: ui-state-gate.sh blocks the first style edit of this session until a real state query has returned a real value.</system-reminder>"
fi
exit 0
