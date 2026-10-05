#!/usr/bin/env bash
# babysitting-nudge.sh — UserPromptSubmit hook.
#
# Two behaviours, both non-blocking (always exit 0; stdout is injected as context):
#
# 1. Babysitting nudge: counts CONSECUTIVE bare continuation prompts per session
#    ("continue", "retry", "keep going", ...). On the 3rd in a row, injects a
#    reminder to restate a done-condition + verify command and hand back a
#    /loop or /goal instead of hand-cranking. Any non-continuation prompt resets
#    the counter. (History showed continue=592, retry=88, keep going, ... with
#    /loop=0 and /goal=0 — this operationalises the CLAUDE.md directive.)
#
# 2. Commit/push alias: bare "commit this" / "push it" / "ship it" get routed to
#    the commit-commands plugin instead of being typed as prose each time.
#
# Disable: CLAUDE_SKIP_HOOKS=babysitting-nudge
SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,babysitting-nudge,*) exit 0 ;; esac

INPUT=$(cat 2>/dev/null || true)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null || true)
SID=$(printf '%s' "$SID" | tr -dc 'A-Za-z0-9_-'); SID=${SID:-default}
[ -z "$PROMPT" ] && exit 0

STATE_DIR="$HOME/.claude/state"
mkdir -p "$STATE_DIR" 2>/dev/null || true
CNT_FILE="$STATE_DIR/babysit-${SID}.count"

# Normalise: lowercase, strip leading/trailing whitespace and trailing punctuation.
norm=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/[.!?, ]+$//')

# --- Probe-first nudge (external-dependency keywords; extra line, non-exclusive) ---
# workflow-rules First-Pass Quality Gates: external deps were the probe-able
# dead-ends (WhatsApp/Outlook/SharePoint, wrong_approach 45/148).
case "$norm" in
  *whatsapp*|*sharepoint*|*outlook*|*linkedin*|*tiktok*|*oauth*|*mdm*|*sso*|*passkey*|*"admin consent"*|*"single sign"*|*"microsoft graph"*|*"google auth"*|*"third-party api"*|*"third party api"*|*pairing*)
    echo "<system-reminder>Probe-first is a BLOCKING GATE (workflow-rules First-Pass Quality Gates): this prompt touches an external dependency (WhatsApp/SharePoint/Outlook/LinkedIn/TikTok/OAuth/SSO/passkey/admin-consent/MS-Graph/MDM/third-party pairing). Run the auth/feasibility probe AND name a fallback BEFORE building any flow or UI around it. No probe → no build. (These recur as dead-ends: Outlook passkey, SharePoint admin-consent, WhatsApp 401, TikTok approval, LinkedIn upload.)</system-reminder>" ;;
esac

# --- Commit / push aliases (checked first; these are not continuations) ---
case "$norm" in
  "commit this"|"commit"|"commit it"|"commit that"|"just commit")
    echo "<system-reminder>Shortcut: run \`/commit-commands:commit\` for a verified commit (it stages + writes a conventional message). The pre-commit + codex hooks already guard it.</system-reminder>"
    : > "$CNT_FILE"; exit 0 ;;
  "push it"|"ship it"|"push this"|"push"|"commit and push"|"commit push")
    echo "<system-reminder>Shortcut: run \`/commit-commands:commit-push-pr\` to commit, push, and open a PR in one shot. The pre-push codex review still runs.</system-reminder>"
    : > "$CNT_FILE"; exit 0 ;;
esac

# --- Continuation detection ---
is_cont=0
case "$norm" in
  "continue"|"continue please"|"please continue"|"keep going"|"keep going please"\
  |"retry"|"try again"|"go on"|"carry on"|"proceed"|"resume"|"next"\
  |"ok continue"|"ok go"|"ok keep going"|"continue."|"more"|"and"|"go ahead")
    is_cont=1 ;;
esac

if [ "$is_cont" -eq 1 ]; then
  n=0; [ -f "$CNT_FILE" ] && n=$(cat "$CNT_FILE" 2>/dev/null | tr -dc '0-9'); n=${n:-0}
  n=$((n + 1))
  if [ "$n" -ge 3 ]; then
    echo "<system-reminder>You've manually continued ${n}x in a row (\`/loop\`=0, \`/goal\`=0 historically). If this is objective-shaped work, stop hand-cranking: restate the done-condition + a verify command, then hand it to \`/loop\` (iterate-until-condition) or \`/goal\` (multi-step outcome + final verify) so it runs autonomously. Ignore if you're deliberately steering step-by-step.</system-reminder>"
    : > "$CNT_FILE"   # reset so it nudges every 3, not every turn after
  else
    printf '%s' "$n" > "$CNT_FILE"
  fi
else
  : > "$CNT_FILE"   # reset streak on any substantive prompt
fi

exit 0
