#!/usr/bin/env bash
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

# --- opus-on-trivial guard (cost discipline) -------------------------------
# model is present here. Log every opus subagent call for spend visibility
# (root cause of the prior opus-on-trivial leak was *no* tracking), and block
# opus for clearly-cheap agent types where it is pure waste. Architecture-class
# types still get opus. Fail-open on any error; override once with OPUS_OK=1.
if [[ "$model" == "opus" ]]; then
  log_dir="${HOME}/.claude/logs"
  mkdir -p "$log_dir" 2>/dev/null || true
  printf '%s\topus\t%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)" "$subagent_type" \
    >> "$log_dir/opus-agent-calls.log" 2>/dev/null || true

  if [[ "${OPUS_OK:-0}" != "1" ]]; then
    case "$subagent_type" in
      Explore|explore|oh-my-claudecode:explore|statusline-setup|writer|oh-my-claudecode:writer)
        cat >&2 <<EOF
opus is wasteful for subagent_type=$subagent_type (search/format/boilerplate work).
Per your model-routing policy, pick a cheaper tier:

  - model: "haiku"   → file searches, formatting, lookups
  - model: "sonnet"  → standard implementation, editing, review

Retry with haiku/sonnet, or export OPUS_OK=1 to override this once.
EOF
        exit 2
        ;;
    esac
  fi

  # session-spend tripwire: past OPUS_SESSION_LIMIT opus calls in one session,
  # require an explicit ack. Catches deliberate-opus-on-trivial that the cheap-type
  # list can't see. Counter is per session_id; fail-open; bypass with OPUS_OK=1.
  session_id="$(jq -r '.session_id // "unknown"' <<<"$payload")"
  threshold="${OPUS_SESSION_LIMIT:-10}"
  state_dir="${HOME}/.claude/state/opus-tripwire"
  mkdir -p "$state_dir" 2>/dev/null || true
  count_file="$state_dir/${session_id}"
  count="$(cat "$count_file" 2>/dev/null || echo 0)"
  case "$count" in *[!0-9]*) count=0 ;; esac
  count=$((count + 1))
  printf '%s\n' "$count" > "$count_file" 2>/dev/null || true
  if [[ "${OPUS_OK:-0}" != "1" && "$count" -gt "$threshold" ]]; then
    cat >&2 <<EOF
opus subagent tripwire: $count opus Agent calls this session (limit ${threshold}).
This is the pattern behind opus-on-trivial overspend. Confirm THIS call really needs
opus (architecture / hard debug after >=2 sonnet passes). To proceed, export OPUS_OK=1.
Raise the budget with OPUS_SESSION_LIMIT=N. Counter is per session_id.
EOF
    exit 2
  fi
fi

exit 0
