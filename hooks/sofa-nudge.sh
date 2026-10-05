#!/usr/bin/env bash
# sofa-nudge.sh: UserPromptSubmit hook. Advisory, never blocks.
#
# Why: SOFA (Stack Overflow for Agents) was connected 30 Sep 2026 and the user asked
# for it to be used without him having to ask. Its MCP tools are DEFERRED, so
# nothing surfaces them at the moment they matter. Same shape as shadcn-nudge.sh:
# re-inject the rule next to the request so it binds.
#
# Two triggers:
#   debugging-shaped prompt  -> search SOFA before diagnosing
#   "that worked" prompt     -> offer to share the fix as a TIL (ask first, the
#                               agent publishes directly with no draft step)
#
# Disable: CLAUDE_SKIP_HOOKS=sofa-nudge
SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,sofa-nudge,*) exit 0 ;; esac
command -v jq >/dev/null 2>&1 || exit 0

set -uo pipefail
INPUT=$(cat 2>/dev/null || true)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)
[ -z "$PROMPT" ] && exit 0
low=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')

debug='error|exception|stack ?trace|traceback|bug|broken|failing|fails|failed|crash|not working|doesn.?t work|won.?t (start|build|run|load|compile)|can.?t (get|make) .* work|why (is|does|won|isn|doesn)|debug|segfault|undefined is not|cannot find module|permission denied|timeout|timed out|(500|502|503|404) (error|internal|not found)|returns? (a )?(500|404)'
worked='that worked|it works now|works now|fixed it|that fixed|sorted it|all working|finally work|nailed it|that did it|working now'

if printf '%s' "$low" | grep -qE "$worked"; then
  cat <<'NUDGE'
<system-reminder>SOFA: the user just confirmed a fix worked. If the fix was non-obvious (a gotcha, a misleading error, a workaround someone else would hit), end your reply with ONE line offering to share it on Stack Overflow for Agents as a TIL. Do not post without a yes: the agent publishes directly, no draft. When posting, strip anything identifying: no names, no ParentCo or client repo names, no internal URLs, paths or code. Generic problem, cause, fix. Tools are deferred: ToolSearch "select:mcp__sofa__sofa_share_til,mcp__sofa__sofa_search" (search first to avoid a duplicate). Trivial fix: say nothing.</system-reminder>
NUDGE
  exit 0
fi

if printf '%s' "$low" | grep -qE "$debug"; then
  cat <<'NUDGE'
<system-reminder>SOFA: this looks like debugging. Before diagnosing from scratch, search Stack Overflow for Agents for the error or symptom (a generic phrasing, no internal names or code). Tools are deferred: ToolSearch "select:mcp__sofa__sofa_search,mcp__sofa__sofa_get_post,mcp__sofa__sofa_vote". Use a hit only after checking it against this codebase. If an answer helped, vote on it. Skip the search when the cause is already obvious from the output in front of you.</system-reminder>
NUDGE
fi
exit 0
