#!/bin/zsh
# matcha-run - delegate an AGENTIC task to the Harris Matcha gateway.
#
# Unlike matcha.sh (one API call, no tools) this runs the real Claude Code
# binary headless against Matcha, so it can read the repo, grep it and, with
# --write, edit it. The Codex shape, different engine, billed to Matcha.
#
# Usage:
#   matcha-run.sh [opts] "task"
#     --write            allow Edit/Write/Bash in the working dir (default: read only)
#     --tier deep|standard|fast   default deep
#     --dir PATH         working dir (default: cwd)
#     --budget USD       spend cap (default 2.00)
#     --timeout SEC      wall clock cap (default 900)
#     --model NAME       force a model, skips auto selection
#
# Exit 0 = task finished. Non-zero = config problem, timeout or run error.

CFG="$HOME/.claude/matcha.env"
CACHE="$HOME/.claude/.matcha-models.json"
[[ -r "$CFG" ]] || { print -u2 "matcha-run: missing $CFG"; exit 1; }
source "$CFG"
KEY="$(security find-generic-password -a "$USER" -s matcha-api-key -w 2>/dev/null)" \
  || { print -u2 "matcha-run: key not in keychain (service: matcha-api-key)"; exit 1; }

WRITE=0; TIER=deep; DIR="$PWD"; BUDGET=2.00; TIMEOUT=900; FORCE_MODEL=""
typeset -a WORDS
need() { [[ $# -ge 2 ]] || { print -u2 "matcha-run: $1 needs a value"; exit 1; }; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --write)   WRITE=1; shift ;;
    --tier)    need "$@"; TIER="$2"; shift 2 ;;
    --dir)     need "$@"; DIR="$2"; shift 2 ;;
    --budget)  need "$@"; BUDGET="$2"; shift 2 ;;
    --timeout) need "$@"; TIMEOUT="$2"; shift 2 ;;
    --model)   need "$@"; FORCE_MODEL="$2"; shift 2 ;;
    --) shift; WORDS+=("$@"); break ;;
    -*) print -u2 "matcha-run: unknown flag $1"; exit 1 ;;
    # A flag written after the task must still be honoured, not swallowed into
    # the prompt text, so keep scanning instead of breaking here.
    *) WORDS+=("$1"); shift ;;
  esac
done
TASK="${WORDS[*]}"
case "$TIER" in
  deep|standard|fast) ;;
  *) print -u2 "matcha-run: unknown tier '$TIER' (deep, standard or fast)"; exit 1 ;;
esac
# A bad number here would otherwise fire the watchdog instantly and be reported
# as a real timeout, which sends you hunting a hang that never happened.
[[ "$TIMEOUT" == <-> ]] || { print -u2 "matcha-run: --timeout must be whole seconds, got '$TIMEOUT'"; exit 1; }
[[ "$BUDGET" =~ '^[0-9]+(\.[0-9]+)?$' ]] || { print -u2 "matcha-run: --budget must be a number, got '$BUDGET'"; exit 1; }
[[ -n "$TASK" ]] || { print -u2 "matcha-run: no task given"; exit 1; }
[[ -d "$DIR" ]]  || { print -u2 "matcha-run: no such directory: $DIR"; exit 1; }

# --- live model list ------------------------------------------------------
# Never guess a deployment name: ask the gateway. Cached for a day, because a
# wrong name is reported as HTTP 500 and retried with backoff, which hangs.
refresh_models() {
  curl -s -m 30 "$MATCHA_BASE_URL/v1/models/" \
    -H "MATCHA-API-KEY: $KEY" -H "anthropic-version: 2023-06-01" > "$CACHE.tmp" 2>/dev/null
  if python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d.get("data")' "$CACHE.tmp" 2>/dev/null; then
    mv "$CACHE.tmp" "$CACHE"; return 0
  fi
  rm -f "$CACHE.tmp"; return 1
}
CACHE_AGE=999999
[[ -f "$CACHE" ]] && CACHE_AGE=$(( $(date +%s) - $(stat -f %m "$CACHE") ))
if [[ $CACHE_AGE -gt 86400 ]]; then
  if refresh_models; then
    CACHE_AGE=0
  elif [[ -f "$CACHE" ]]; then
    # Stale but present is the common failure (VPN down). Say so out loud, and
    # refuse outright once it is old enough that the model list is a guess.
    if [[ $CACHE_AGE -gt 604800 ]]; then
      print -u2 "matcha-run: gateway unreachable and the model list is over a week old. Refusing to guess."
      exit 1
    fi
    print -u2 "matcha-run: gateway unreachable, using a model list $(( CACHE_AGE / 3600 ))h old."
  fi
fi
[[ -f "$CACHE" ]] || { print -u2 "matcha-run: cannot reach gateway to list models (VPN? gateway down?)"; exit 1; }

# Auto selection: newest generation that is actually live in the tier's family.
# Adding a newer model to the gateway upgrades this with no edit here.
pick_model() {
  python3 - "$CACHE" "$1" <<'PY'
import json, re, sys
ids = [m["id"] for m in json.load(open(sys.argv[1]))["data"]]
fam = {"deep": "opus", "standard": "sonnet", "fast": "haiku"}.get(sys.argv[2], "opus")
# ranked by (major, minor) descending, so claude-opus-5 beats claude-opus-4-6
def ver(i):
    tail = i.split(fam, 1)[1] if fam in i else ""
    nums = [int(x) for x in re.findall(r"\d+", tail)]
    # Drop trailing date stamps like -20251001, otherwise a legacy dated
    # deployment sorts above every real version and gets picked silently.
    nums = [n for n in nums if n < 100000]
    return tuple(nums) if nums else (0,)
cand = sorted([i for i in ids if fam in i], key=ver, reverse=True)
print(cand[0] if cand else "")
PY
}
if [[ -n "$FORCE_MODEL" ]]; then MODEL="$FORCE_MODEL"; else MODEL="$(pick_model "$TIER")"; fi
SMALL="$(pick_model fast)"
[[ -n "$MODEL" ]] || { print -u2 "matcha-run: no model in tier '$TIER' on this gateway"; exit 1; }
[[ -n "$SMALL" ]] || SMALL="$MODEL"

# Prove the pick is a real deployment before handing over, else a 500 storm.
"$HOME/.claude/scripts/matcha-preflight.sh" "$MODEL" || exit 1

# --- tools ----------------------------------------------------------------
# --restricted drops the code-running tools AND ignores user/project/local
# settings, so your hooks never fire inside the nested run. It also confines
# the file tools to the working directory.
if [[ $WRITE -eq 1 ]]; then
  TOOLS="Read,Grep,Glob,Edit,Write,Bash"
  PERM="acceptEdits"
else
  TOOLS="Read,Grep,Glob"
  PERM="default"
fi

# Log goes to a temp dir, never into $DIR: a stray .matcha-run.json in a repo
# shows up in git status and gets committed by accident.
LOGDIR="${TMPDIR:-/tmp}/matcha-run"
mkdir -p "$LOGDIR"
LOG="${MATCHA_RUN_LOG:-$LOGDIR/$(date +%Y%m%d-%H%M%S)-$$.json}"
print -u2 "matcha-run: model=$MODEL tier=$TIER write=$WRITE budget=\$$BUDGET timeout=${TIMEOUT}s dir=$DIR"

cd "$DIR" || exit 1
env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT -u CLAUDE_CODE_SESSION_ID \
    -u CLAUDE_CODE_CHILD_SESSION -u CLAUDE_CODE_MESSAGING_SOCKET \
    -u CLAUDE_CODE_MESSAGING_TOKEN -u CLAUDE_CODE_BRIDGE_SESSION_ID \
    -u CLAUDE_PID -u CLAUDE_EFFORT -u CODEX_COMPANION_TRANSCRIPT_PATH \
    -u CLAUDE_PLUGIN_DATA -u ANTHROPIC_API_KEY \
    ANTHROPIC_BASE_URL="$MATCHA_BASE_URL" ANTHROPIC_AUTH_TOKEN="$KEY" \
    ANTHROPIC_MODEL="$MODEL" ANTHROPIC_SMALL_FAST_MODEL="$SMALL" \
    claude -p "$TASK" --restricted --tools "$TOOLS" --strict-mcp-config \
      --permission-mode "$PERM" --output-format json --max-budget-usd "$BUDGET" \
      > "$LOG" 2>"$LOG.err" &
RUN_PID=$!
( sleep "$TIMEOUT"; kill -TERM $RUN_PID 2>/dev/null ) &
WATCHDOG=$!
wait $RUN_PID; RC=$?
kill $WATCHDOG 2>/dev/null

if [[ $RC -eq 143 || $RC -eq 137 ]]; then
  print -u2 "matcha-run: killed at the ${TIMEOUT}s wall clock cap. Partial log: $LOG"
  exit 124
fi

python3 - "$LOG" "$LOG.err" "$RC" <<'PY'
import json, sys, os
log, errf, rc = sys.argv[1], sys.argv[2], int(sys.argv[3])
try:
    d = json.load(open(log))
except Exception:
    err = open(errf).read() if os.path.exists(errf) else ""
    sys.stderr.write("matcha-run: no usable result.\n" + err[-800:] + "\n"); sys.exit(1)
print(d.get("result", ""))
sys.stderr.write("matcha-run: cost $%.4f, %s turns, error=%s\n"
                 % (d.get("total_cost_usd") or 0, d.get("num_turns"), d.get("is_error")))
# The run's own exit code counts too: a crash after valid JSON was
# otherwise reported as a clean finish.
sys.exit(1 if (d.get("is_error") or rc != 0) else 0)
PY
