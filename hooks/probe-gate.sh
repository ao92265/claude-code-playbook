#!/usr/bin/env bash
# probe-gate.sh - PreToolUse(Edit|Write). The blocking half of the external-dependency gate.
#
# Blocks writing CODE against a service that has not been reached this session.
# The rule already existed in workflow-rules.md and was ignored because nothing
# enforced it: "every one of those was a 5-minute probe and a dead-ended session".
# Command failures are 1,556 of 2,779 recorded tool errors, the single largest
# category, and the only not-achieved session in the whole facet sample was a
# Microsoft passkey wall that a first-minute probe would have exposed.
#
# Deliberately narrow, because a gate that cries wolf gets disabled:
#   - only code files, never docs, notes or markdown
#   - only a real client reach (a host, an SDK import, an authed CLI call),
#     never a bare mention of a company name
#   - once per service per session, so the second file is free
#
# Exit codes: 0 allow, 2 block
# Disable: CLAUDE_SKIP_HOOKS=probe
SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,probe,*) exit 0 ;; esac
command -v jq >/dev/null 2>&1 || exit 0

set -uo pipefail
INPUT=$(cat 2>/dev/null || true)
printf '%s' "$INPUT" | jq -e . >/dev/null 2>&1 || exit 0

SID=$(printf '%s' "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null || true)
SID=$(printf '%s' "$SID" | tr -dc 'A-Za-z0-9_-'); SID=${SID:-default}
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
[ -n "$FILE" ] || exit 0

# Code only. Prose that mentions a service is not an integration.
case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.py|*.rb|*.go|*.rs|*.java|*.cs|*.php|*.sh|*.mts) ;;
  *) exit 0 ;;
esac
case "$FILE" in
  *test*|*spec*|*/tests/*|*/__tests__*|*fixture*|*mock*|*smoke*|*sample*) exit 0 ;;
esac

BODY=$(printf '%s' "$INPUT" | jq -r '
  [ (.tool_input.content // ""), (.tool_input.new_string // "") ]
  | map(select(. != "")) | join("\n")' 2>/dev/null || true)
[ -n "$BODY" ] || exit 0
low=$(printf '%s' "$BODY" | tr '[:upper:]' '[:lower:]')

STATE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/state/probe"

# service slug | what it looks like in code | how to probe it. Every match is
# collected first, then reported ONCE, because exiting on the first unstamped
# service turned a single file into one block per service on successive retries.
HITS=""; HOWTO=""
consider() {
  svc="$1"; pat="$2"; how="$3"
  printf '%s' "$low" | grep -qE "$pat" || return 0
  [ -f "$STATE_DIR/${SID}--${svc}" ] && return 0
  [ -f "$STATE_DIR/${SID}--waived-${svc}" ] && return 0
  HITS="${HITS}${HITS:+ }${svc}"
  HOWTO="${HOWTO}  ${svc}: ${how}
"
}

consider outlook    'graph\.microsoft\.com|outlook\.office|@microsoft/microsoft-graph|msal' \
  'curl -s -o /dev/null -w "%{http_code}" https://graph.microsoft.com/v1.0/me'
consider sharepoint '\.sharepoint\.com|sp-rest|pnpjs' \
  'curl -s -o /dev/null -w "%{http_code}" https://<tenant>.sharepoint.com/_api/web'
consider linkedin   'api\.linkedin\.com|linkedin\.com/v2' \
  'curl -s -o /dev/null -w "%{http_code}" https://api.linkedin.com/v2/me'
consider tiktok     'open\.tiktokapis\.com|tiktok\.com/v2|tiktokv' \
  'curl -s -o /dev/null -w "%{http_code}" https://open.tiktokapis.com/v2/user/info/'
consider whatsapp   'web\.whatsapp\.com|graph\.facebook\.com/v[0-9]+/[0-9]+/messages|whatsapp-web' \
  'curl -s -o /dev/null -w "%{http_code}" https://graph.facebook.com/v20.0/me'
consider atlassian  '\.atlassian\.net|jira-client|confluence-api|jira/rest' \
  'curl -s -o /dev/null -w "%{http_code}" -u "$USER:$TOKEN" https://<site>.atlassian.net/rest/api/3/myself'
consider figma      'api\.figma\.com|figma-api' \
  'curl -s -o /dev/null -w "%{http_code}" -H "X-Figma-Token: $TOK" https://api.figma.com/v1/me'
consider teams      'teams\.microsoft\.com|botframework' \
  'curl -s -o /dev/null -w "%{http_code}" https://graph.microsoft.com/v1.0/me/joinedTeams'

[ -n "$HITS" ] || exit 0

mkdir -p "$STATE_DIR" 2>/dev/null || true
for svc in $HITS; do : > "$STATE_DIR/${SID}--waived-${svc}" 2>/dev/null || true; done

cat >&2 <<MSG
[probe-gate] BLOCKED. Writing code for an unprobed service: $HITS

File: $FILE

workflow-rules.md calls this a blocking gate, not advice, and it has been
ignored because nothing enforced it. Failed commands are the largest error
category in your corpus, and the one session in the sample that achieved
nothing died at a Microsoft sign-in prompt after the code was already written.

Probe each of these, then say what the fallback is if one fails:

$HOWTO
Probed somewhere this hook cannot see (browser MCP, a manual login)? Record it:
  echo "probe-ok:<service>"

Every service named above has now been waived for this session, so the retry
goes straight through. This fires once so it cannot become noise.
MSG
exit 2
