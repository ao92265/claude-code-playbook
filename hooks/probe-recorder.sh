#!/usr/bin/env bash
# probe-recorder.sh - PostToolUse. The passive half of the external-dependency gate.
#
# Why: workflow-rules.md has said "probe first on external dependencies, this is a
# blocking gate, not advice" for months, and nothing enforced it. It stayed a
# sentence. In the sampled sessions the only outright failure was an Outlook web
# reply that died at a Microsoft passkey prompt, and an Atlassian MCP burned a
# whole session the same way. Both were knowable in the first minute.
#
# This watches for a real reach at a real service and stamps it. probe-gate.sh
# reads the stamps. A stamp cannot be produced by asserting that you probed:
# it needs a command that named the host and came back with something.
#
# Silent always, exits 0 always.
#
# Disable: CLAUDE_SKIP_HOOKS=probe
SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,probe,*) exit 0 ;; esac
command -v jq >/dev/null 2>&1 || exit 0

set -uo pipefail
INPUT=$(cat 2>/dev/null || true)
printf '%s' "$INPUT" | jq -e . >/dev/null 2>&1 || exit 0

SID=$(printf '%s' "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null || true)
SID=$(printf '%s' "$SID" | tr -dc 'A-Za-z0-9_-'); SID=${SID:-default}

STATE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/state/probe"
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0

SENT=$(printf '%s' "$INPUT" | jq -r '
  [ (.tool_input.command // ""), (.tool_input.url // ""), (.tool_input.code // ""),
    (.tool_input.query // "") ]
  | map(select(. != "")) | join(" ")' 2>/dev/null || true)
[ -n "$SENT" ] || exit 0

# The services that have actually cost sessions, from workflow-rules.md plus the
# ones the session facets show dying. Each maps a host or CLI to one slug so the
# gate can ask "was THIS thing probed", not "was anything probed".
stamp() {
  printf 'at=%s\nvia=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$(printf '%s' "$SENT" | tr -d '\n' | cut -c1-200)" \
    > "$STATE_DIR/${SID}--$1" 2>/dev/null || true
}

# An explicit stamp for a probe done somewhere this hook cannot see: a browser
# MCP login, a manual check. Deliberate, and it shows up in the transcript.
MANUAL=$(printf '%s' "$SENT" | grep -oE 'probe-ok:[a-z0-9-]+' | head -1 | cut -d: -f2 || true)
if [ -n "$MANUAL" ]; then stamp "$MANUAL"; exit 0; fi

# Everything below needs a response. A command that named the host and returned
# nothing is a failed probe, and a failed probe must not unlock the gate.
OUT=$(printf '%s' "$INPUT" | jq -r '
  (.tool_response // empty) as $r
  | if ($r|type) == "string" then $r
    elif ($r|type) == "object" then
      ([$r.stdout // "", $r.stderr // "", $r.output // "", ($r.content // "" | tostring),
        ($r.result // "" | tostring)] | map(select(. != "")) | join("\n"))
    else "" end' 2>/dev/null || true)
[ -n "$(printf '%s' "$OUT" | tr -d '[:space:]')" ] || exit 0

low=$(printf '%s' "$SENT" | tr '[:upper:]' '[:lower:]')
case "$low" in
  *graph.microsoft.com*|*outlook.office*|*outlook.com*)   stamp outlook ;;
esac
case "$low" in *sharepoint.com*|*.sharepoint*)            stamp sharepoint ;; esac
case "$low" in *linkedin.com*)                            stamp linkedin ;; esac
case "$low" in *tiktok.com*|*tiktokv*)                    stamp tiktok ;; esac
case "$low" in *web.whatsapp.com*|*whatsapp*)             stamp whatsapp ;; esac
case "$low" in *atlassian.net*|*atlassian.com*|*jira*|*confluence*) stamp atlassian ;; esac
case "$low" in *api.figma.com*|*figma.com*)               stamp figma ;; esac
case "$low" in *teams.microsoft.com*)                     stamp teams ;; esac
case "$low" in *login.microsoftonline.com*|*oauth*|*/token*|*saml*|*openid*) stamp oauth ;; esac
case "$low" in *"gh auth status"*|*api.github.com*)       stamp github ;; esac

find "$STATE_DIR" -type f -mtime +14 -delete 2>/dev/null || true
exit 0
