#!/bin/bash
# PreToolUse hook: block Agent tool calls missing an explicit `model` field.
# Install by adding a PreToolUse matcher for "Agent" in settings.json that
# points to this script. Without it, Claude inherits the parent model
# (typically opus) into every subagent and burns ~5x the tokens.
#
# Exit codes:
#   0   allow the call
#   2   block (stderr shown to Claude as a tool-use error so it retries)
#
# Emergency override: set REQUIRE_AGENT_MODEL_DISABLED=1.

set -euo pipefail

if [[ "${REQUIRE_AGENT_MODEL_DISABLED:-0}" == "1" ]]; then
  exit 0
fi

# If CLAUDE_CODE_SUBAGENT_MODEL is set, it overrides everything in the binary
# resolution order, so the invocation param does not matter — allow the call.
if [[ -n "${CLAUDE_CODE_SUBAGENT_MODEL:-}" ]]; then
  exit 0
fi

payload="$(cat)"

# If jq is unavailable, fail open rather than blocking everything.
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

tool_name="$(jq -r '.tool_name // empty' <<<"$payload")"
if [[ "$tool_name" != "Agent" && "$tool_name" != "Task" ]]; then
  exit 0
fi

model="$(jq -r '.tool_input.model // empty' <<<"$payload")"
subagent_type="$(jq -r '.tool_input.subagent_type // "<unset>"' <<<"$payload")"

if [[ -z "$model" ]]; then
  cat >&2 <<EOF
Agent invocation is missing an explicit \`model\` field (subagent_type=$subagent_type).

Without it, the subagent inherits the parent conversation model (typically
opus), which silently multiplies token cost. Pick one:

  - model: "haiku"   → file searches, formatting, boilerplate
  - model: "sonnet"  → implementation, editing, tests, code review (default)
  - model: "opus"    → architecture, hard debugging after >=2 sonnet passes

Retry the call with \`model\` specified. To bypass this hook in an emergency,
export REQUIRE_AGENT_MODEL_DISABLED=1 or set CLAUDE_CODE_SUBAGENT_MODEL.
EOF
  exit 2
fi

exit 0
