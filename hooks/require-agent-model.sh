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
# Emergency override, the user only: REQUIRE_AGENT_MODEL_DISABLED=1 exported before
# `claude` starts. Not settable from inside a session.#
# The switch below is HUMAN-ONLY BY DESIGN, and must stay that way. A hook only
# ever sees the environment `claude` was launched with, so this variable has to
# be exported BEFORE the session starts (the user's ~/.zshrc does this for two
# hooks). Do not "fix" that by also reading a state file or an inline
# `VAR=1 <command>` prefix: this gate exists to stop the agent, and any switch
# the agent can write is a switch the agent can flip. Measured 2026-08-19:
# `CLAUDE_SKIP_HOOKS=firewall rm -rf <path>` was correctly still blocked.


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
# Non-Agent/Task tools pass untouched. This includes the Workflow tool, which
# spawns agents without per-call model params — that path is legitimate (its
# agents resolve models from their definitions), not a gap in this gate.
if [[ "$tool_name" != "Agent" && "$tool_name" != "Task" ]]; then
  exit 0
fi

model="$(jq -r '.tool_input.model // empty' <<<"$payload")"
subagent_type="$(jq -r '.tool_input.subagent_type // "<unset>"' <<<"$payload")"

# --- agent-definition model lookup ------------------------------------------
# OMC/user/project agent definitions can pin `model:` in their frontmatter
# (all 19 of ~/.claude/agents/*.md do). A spawn that omits `model` for those
# types is legitimate — the definition resolves it — so allow it instead of
# blocking. Only plain spawns with no definition-pinned model get blocked.
agent_def_has_model() {
  local type="$1"
  local name="${type##*:}"   # strips any plugin prefix, e.g. caveman:cavecrew-builder
  local dir f
  for dir in "$PWD/.claude/agents" "${HOME}/.claude/agents"; do
    for f in "$dir/$type.md" "$dir/$name.md"; do
      [[ -f "$f" ]] || continue
      # model: <value> inside the first --- frontmatter block
      if awk '/^---$/{n++; next} n==1 && /^model:[[:space:]]*[^[:space:]]/{found=1; exit} n>=2{exit} END{exit !found}' "$f"; then
        return 0
      fi
    done
  done
  return 1
}

if [[ -z "$model" && "$subagent_type" != "<unset>" ]] && agent_def_has_model "$subagent_type"; then
  exit 0
fi

if [[ -z "$model" ]]; then
  cat >&2 <<EOF
Agent invocation is missing an explicit \`model\` field (subagent_type=$subagent_type).

Without it, the subagent inherits the parent conversation model (typically
opus), which silently multiplies token cost. Pick one:

  - model: "haiku"   → file searches, formatting, boilerplate
  - model: "sonnet"  → implementation, editing, tests, code review (default)
  - model: "opus"    → architecture, hard debugging after >=2 sonnet passes

Retry the call with \`model\` specified. (Agent types whose definition pins a
\`model:\` in frontmatter pass automatically — this type has none.) Do not try to
export REQUIRE_AGENT_MODEL_DISABLED or CLAUDE_CODE_SUBAGENT_MODEL to get past
this: a hook cannot see a variable exported inside the session, so it will fail
and cost you another turn. Retrying with an explicit model is the only route.
Only the user can disable this, by relaunching with the variable exported.
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
      Explore|explore|statusline-setup)
        cat >&2 <<EOF
opus is wasteful for subagent_type=$subagent_type (search/format/boilerplate work).
Per your model-routing policy, pick a cheaper tier:

  - model: "haiku"   → file searches, formatting, lookups
  - model: "sonnet"  → standard implementation, editing, review

Retry with haiku or sonnet. OPUS_OK=1 works only if the user exported it before
the session started, so exporting it yourself now will not help.
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
opus (architecture / hard debug after >=2 sonnet passes). OPUS_OK=1 only counts
if it was exported before the session started; setting it now cannot work.
Raise the budget with OPUS_SESSION_LIMIT=N. Counter is per session_id.
EOF
    exit 2
  fi
fi

exit 0
