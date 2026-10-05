#!/usr/bin/env bash
# shadcn-nudge.sh — UserPromptSubmit hook.
#
# Why: measured 2026-08-25 from 30 days of session logs. The shadcn MCP server
# is configured globally and was called ZERO times, across 2,476 ToolSearch
# calls and 292 sessions that touched UI files. Six repos have shadcn
# components on disk and four carry components.json, so the stack is real and
# the server works (probed, it starts and answers). The tools are simply
# DEFERRED: nothing surfaces them at the moment a component is being written,
# and the only pointer is one passive line in design-rules.md.
#
# Natural experiment supporting this: context7 ships an MCP instruction block
# in the system prompt and got 12 searches. shadcn ships none and got 0.
#
# Same shape as ui-state-nudge.sh: re-inject the rule next to the request so it
# binds. Hard-gated on a real shadcn project marker, so it stays silent in the
# Angular and non-UI repos.
#
# Disable: CLAUDE_SKIP_HOOKS=shadcn-nudge
SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,shadcn-nudge,*) exit 0 ;; esac
command -v jq >/dev/null 2>&1 || exit 0

set -uo pipefail
INPUT=$(cat 2>/dev/null || true)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)
[ -z "$PROMPT" ] && exit 0
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
[ -z "$CWD" ] && CWD="$PWD"
[ -d "$CWD" ] || exit 0

# --- hard gate: is this actually a shadcn project? walk up, cap at 6 levels ---
is_shadcn_project() {
  local d="$1" i=0
  while [ "$i" -lt 6 ] && [ -n "$d" ] && [ "$d" != "/" ]; do
    if [ -f "$d/components.json" ] || [ -d "$d/components/ui" ] || [ -d "$d/src/components/ui" ]; then
      return 0
    fi
    d=$(dirname "$d"); i=$((i+1))
  done
  return 1
}
is_shadcn_project "$CWD" || exit 0

# --- intent gate: component / UI construction work ---
nouns='component|button|dialog|modal|dropdown|combobox|checkbox|radio|switch|slider|tabs?|accordion|popover|tooltip|toast|sonner|sheet|drawer|card|badge|avatar|data ?table|form field|textarea|calendar|date ?picker|command palette|sidebar|navbar|breadcrumb|pagination|skeleton|alert|progress bar|separator|scroll area|toggle|carousel|collapsible|context menu|menubar|navigation menu|hover card|empty state|design system'
verbs='build|add|create|make|implement|design|style|redesign|refactor|wire up|scaffold|replace|swap'

low=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')
printf '%s' "$low" | grep -qE "$nouns" || exit 0
printf '%s' "$low" | grep -qE "$verbs" || exit 0

cat <<'NUDGE'
<system-reminder>shadcn is available here and this repo is a shadcn project (components.json / components/ui present). Its MCP tools are DEFERRED, so they are invisible until you fetch them. Do this BEFORE hand-rolling any primitive:

ToolSearch with query "select:mcp__shadcn__search_items_in_registries,mcp__shadcn__view_items_in_registries,mcp__shadcn__get_add_command_for_items,mcp__shadcn__get_item_examples_from_registries"

Then search the registry for the component, view its real source, and use get_add_command_for_items to install it. design-rules: pull real components, do not hand-roll primitives. Measured 25 Aug 2026: this server had been called zero times in 30 days while 292 sessions did UI work, which is why this reminder exists.</system-reminder>
NUDGE
exit 0
