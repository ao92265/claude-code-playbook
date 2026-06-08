#!/usr/bin/env bash
# Shared-state helpers for pr-fleet workers.
# Atomic claim/release/update against .omc/state/pr-swarm.json.
# Lock via mkdir-as-mutex (POSIX, no flock dep).

set -uo pipefail

STATE_DIR="${PR_FLEET_STATE_DIR:-.omc/state}"
STATE_FILE="$STATE_DIR/pr-swarm.json"
LOCK_DIR="$STATE_DIR/.pr-swarm.lock"

mkdir -p "$STATE_DIR"
[ -f "$STATE_FILE" ] || echo '{"prs":{}}' > "$STATE_FILE"

_lock() {
  local tries=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    tries=$((tries+1))
    if [ "$tries" -gt 100 ]; then
      echo "pr-fleet: lock timeout on $LOCK_DIR" >&2
      return 1
    fi
    sleep 0.1
  done
  return 0
}

_unlock() { rmdir "$LOCK_DIR" 2>/dev/null || true; }

pr_fleet_init() {
  _lock || return 1
  local tmp; tmp=$(mktemp)
  jq --argjson prs "$(printf '%s\n' "$@" | jq -R . | jq -s .)" '
    reduce $prs[] as $n (.; .prs[$n] //= {status:"pending", claimed_by:null, attempts:0, blocker_reason:null})
  ' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
  local rc=$?
  _unlock
  return $rc
}

pr_fleet_claim() {
  local pr="$1" worker="$2"
  _lock || return 1
  local current
  current=$(jq -r --arg p "$pr" '.prs[$p].status // "missing"' "$STATE_FILE")
  if [ "$current" != "pending" ]; then
    _unlock
    return 1
  fi
  local tmp; tmp=$(mktemp)
  jq --arg p "$pr" --arg w "$worker" '.prs[$p].status="in_progress" | .prs[$p].claimed_by=$w | .prs[$p].attempts += 1' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
  _unlock
  return 0
}

pr_fleet_done() {
  local pr="$1"
  _lock || return 1
  local tmp; tmp=$(mktemp)
  jq --arg p "$pr" '.prs[$p].status="done"' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
  _unlock
}

pr_fleet_block() {
  local pr="$1" reason="$2"
  _lock || return 1
  local tmp; tmp=$(mktemp)
  jq --arg p "$pr" --arg r "$reason" '.prs[$p].status="blocked" | .prs[$p].blocker_reason=$r' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
  _unlock
}

pr_fleet_report() {
  jq -r '
    .prs | to_entries | group_by(.value.status) | .[] |
    "\(.[0].value.status): \(length)\n  " + (map(.key) | join(", "))
  ' "$STATE_FILE"
}

pr_fleet_preflight() {
  local fail=0
  command -v gh >/dev/null || { echo "preflight: gh missing" >&2; fail=1; }
  command -v jq >/dev/null || { echo "preflight: jq missing" >&2; fail=1; }
  gh auth status >/dev/null 2>&1 || { echo "preflight: gh not authenticated" >&2; fail=1; }
  git fetch --quiet 2>/dev/null || { echo "preflight: git fetch failed" >&2; fail=1; }
  return "$fail"
}

case "${1:-}" in
  init) shift; pr_fleet_init "$@" ;;
  claim) pr_fleet_claim "$2" "$3" ;;
  done) pr_fleet_done "$2" ;;
  block) pr_fleet_block "$2" "$3" ;;
  report) pr_fleet_report ;;
  preflight) pr_fleet_preflight ;;
  *) echo "usage: $0 {init|claim|done|block|report|preflight} [args]" >&2; exit 1 ;;
esac
