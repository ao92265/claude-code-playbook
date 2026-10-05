#!/bin/bash
SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,no-new-dep,*) exit 0 ;; esac
# PreToolUse hook: warn when a NEW dependency name is about to be added to a
# package.json, so the "could a few lines of code do this" question gets asked
# before the package lands rather than at review.
#
# Adopted 27 Aug 2026, the one rule worth lifting from the "17 CLAUDE.md rules"
# article. That article's own economic argument rested on a misread statistic
# (2.74x is CodeRabbit's security-findings figure, not review time), but this
# rule stands on its own and nothing here currently blocks it.
#
# Warn-only by design. Decision on adoption was to measure the firing rate
# first, so every firing is logged and NO_NEW_DEP_BLOCK=1 is the opt-in that
# turns it into a real gate later.
#
# Fires on: a dependency key present in the proposed package.json that is not
#           present in the one currently on disk.
# Silent on: version bumps, removals, lockfiles, every non-package.json file,
#            and a package.json that does not yet exist (new project).
#
# Exit codes:
#   0  no new dependency, or irrelevant file
#   1  warn (new dependency)
#   2  block (only when NO_NEW_DEP_BLOCK=1)
#
# Emergency disable: NO_NEW_DEP_DISABLED=1

set -euo pipefail

if [[ "${NO_NEW_DEP_DISABLED:-0}" == "1" ]]; then exit 0; fi
command -v jq >/dev/null 2>&1 || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

payload="$(cat)"
file="$(jq -r '.tool_input.file_path // empty' <<<"$payload")"
[[ -z "$file" ]] && exit 0

# Only package.json itself. Lockfiles are a consequence, not a decision.
case "$(basename "$file")" in
  package.json) ;;
  *) exit 0 ;;
esac

# A package.json that does not exist yet is a new project, not a new dependency.
[[ -f "$file" ]] || exit 0

# Reconstruct what the file will look like after this tool call.
tool="$(jq -r '.tool_name // empty' <<<"$payload")"
case "$tool" in
  Write)
    proposed="$(jq -r '.tool_input.content // empty' <<<"$payload")"
    ;;
  Edit|MultiEdit)
    # Apply the edit(s) to the on-disk content in memory. Literal replacement
    # only, which matches how Edit actually behaves.
    APPLY_EDITS='
import json, sys
path = sys.argv[1]
payload = json.load(sys.stdin)
ti = payload.get("tool_input", {})
text = open(path, encoding="utf-8").read()
edits = ti.get("edits") or [ti]
for e in edits:
    old, new = e.get("old_string"), e.get("new_string")
    if old is None or new is None:
        continue
    text = text.replace(old, new, -1 if e.get("replace_all") else 1)
sys.stdout.write(text)
'
    proposed="$(python3 -c "$APPLY_EDITS" "$file" <<<"$payload" 2>/dev/null || true)"
    ;;
  *) exit 0 ;;
esac
[[ -z "$proposed" ]] && exit 0

# Diff the dependency NAME sets. Versions are deliberately ignored: a bump is
# not a new decision.
DIFF_DEPS='
import json, sys

FIELDS = ("dependencies", "devDependencies", "peerDependencies", "optionalDependencies")

def names(text):
    try:
        data = json.loads(text)
    except Exception:
        return None
    out = set()
    for f in FIELDS:
        block = data.get(f)
        if isinstance(block, dict):
            out |= set(block)
    return out

proposed = names(sys.stdin.read())
try:
    current = names(open(sys.argv[1], encoding="utf-8").read())
except Exception:
    current = None

# Unparseable on either side means no honest comparison. Stay quiet rather
# than warn on a file we did not understand.
if proposed is None or current is None:
    sys.exit(0)

for n in sorted(proposed - current):
    print(n)
'
added="$(python3 -c "$DIFF_DEPS" "$file" <<<"$proposed" 2>/dev/null || true)"

[[ -z "$added" ]] && exit 0

# Built-ins and already-present tools that cover the most common reaches.
# Not exhaustive, and deliberately short: a wrong suggestion is worse than none.
suggest() {
  case "$1" in
    uuid|nanoid|uuidv4)            echo "crypto.randomUUID() is built into Node" ;;
    left-pad|pad-left|padstart)    echo "String.prototype.padStart is built in" ;;
    # Narrowed on purpose: a bare is-* glob also catches is-ci, is-docker, is-wsl,
    # which are environment probes, not type checks. Wrong advice is worse than none.
    is-array|is-arrayish|isarray|is_array)
                                   echo "Array.isArray is built in" ;;
    is-string|is-number|is-boolean|is-function|is-object|is-plain-object|is-nil|is-undefined)
                                   echo "a typeof check is one line" ;;
    lodash|lodash.*|underscore)    echo "most of it is now built into the language" ;;
    node-fetch|isomorphic-fetch)   echo "fetch is global in Node 18+" ;;
    dotenv)                        echo "node --env-file=.env needs no package" ;;
    rimraf|del|fs-extra)           echo "fs.promises.rm({recursive:true}) is built in" ;;
    querystring|query-string|qs)   echo "URLSearchParams is built in" ;;
    moment|dayjs|date-fns)         echo "Intl.DateTimeFormat covers most formatting" ;;
    chalk|colors|kleur|picocolors) echo "styleText is built into Node 20+" ;;
    axios|request|superagent)      echo "fetch is global in Node 18+" ;;
    *) echo "" ;;
  esac
}

action="warn"
if [[ "${NO_NEW_DEP_BLOCK:-0}" == "1" ]]; then action="block"; fi

# Log every firing so the adoption decision (warn now, tighten only if the rate
# justifies it) can be made from data rather than from a feeling.
log_dir="${HOME}/.claude/hooks/.omc"
mkdir -p "$log_dir" 2>/dev/null || true
repo_dir="$(git -C "$(dirname "$file")" rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
while IFS= read -r dep; do
  [[ -z "$dep" ]] && continue
  printf '%s\t%s\t%s\t%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)" "$repo_dir" "$dep" "$action" \
    >> "$log_dir/no-new-dep.log" 2>/dev/null || true
done <<<"$added"

count="$(grep -c . <<<"$added")"
if [[ "$count" == "1" ]]; then
  echo "New dependency: $added" >&2
else
  echo "New dependencies ($count):" >&2
  while IFS= read -r dep; do [[ -n "$dep" ]] && echo "  $dep" >&2; done <<<"$added"
fi

while IFS= read -r dep; do
  [[ -z "$dep" ]] && continue
  hint="$(suggest "$dep")"
  [[ -n "$hint" ]] && echo "  $dep: $hint" >&2
done <<<"$added"

# This message is addressed to the user, not to the agent, and that is deliberate.
# Confirmed against Anthropic's hook documentation on 27 Aug 2026: on a
# PreToolUse hook only exit 2 puts stderr in front of the model. Any other
# non-zero code lets the action proceed and shows stderr as a transcript
# notice, explicitly "not as context Claude acts on". So in warn mode the
# agent never reads a word of this. You are the only reader.
echo "  Worth a look: could a few lines of code do this job instead?" >&2
echo "  Nothing was blocked. This is logged so the firing rate can be measured." >&2
echo "  Make it a real gate with NO_NEW_DEP_BLOCK=1, or turn it off with NO_NEW_DEP_DISABLED=1." >&2
# No per-command bypass is named here on purpose. A CLAUDE_SKIP_HOOKS prefix
# cannot reach a PreToolUse hook: the hook is spawned as a sibling before the
# command runs, so it never sees that variable. Measured 19 Aug 2026, and four
# other hooks were corrected the same day to stop advertising it.

if [[ "${NO_NEW_DEP_BLOCK:-0}" == "1" ]]; then exit 2; fi
exit 1
