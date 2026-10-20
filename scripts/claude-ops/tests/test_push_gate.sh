#!/bin/bash
# push-gate.py: a session that committed and did not push gets one nudge at stop:
# push, or say why not. Only this session's commits count, real git commands only.
HOOK="$HOME/.claude/hooks/push-gate.py"
FAIL=0
T=$(mktemp -d)
git init -q --bare "$T/remote.git"
git clone -q "$T/remote.git" "$T/repo" 2>/dev/null
git -C "$T/repo" commit -q --allow-empty -m one && git -C "$T/repo" push -q -u origin HEAD 2>/dev/null
OLD="2020-01-01T00:00:00Z"
START=$(date -u -v-1M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '-1 min' +%Y-%m-%dT%H:%M:%SZ)
SID=s1
NL=$'\n'
tx() { # transcript: entrypoint record with session start, then the given bash commands
  jq -cn --arg ts "$START" --arg ep "${EP:-cli}" '{type:"user",timestamp:$ts,entrypoint:$ep,message:{content:"go"}}' > "$T/tx.jsonl"
  for c in "$@"; do jq -cn --arg c "$c" --arg w "${CWD:-}" '{type:"assistant",message:{content:[{type:"tool_use",name:"Bash",input:{command:$c}}]}} + (if $w == "" then {} else {cwd:$w} end)' >> "$T/tx.jsonl"; done; }
run() { # want, label, [stop_hook_active], [entrypoint], [cwd]
  jq -n --arg t "$T/tx.jsonl" --arg cwd "${5:-$T/repo}" --arg s "$SID" --argjson a "${3:-false}" '{session_id:$s, transcript_path:$t, cwd:$cwd, stop_hook_active:$a}' \
    | env -u CLAUDE_SKIP_HOOKS PUSH_GATE_ALLOW="$T/allow" PUSH_GATE_STATE="$T/state" CLAUDE_CODE_ENTRYPOINT="${4:-cli}" python3 "$HOOK" >/dev/null 2>"$T/err"; got=$?
  [ "$got" -eq "$1" ] && echo "OK   $2" || { echo "FAIL $2 (want $1 got $got)"; FAIL=$((FAIL+1)); }; }
fresh() { SID="s$RANDOM$RANDOM"; }

# an old local-only commit made before this session
GIT_COMMITTER_DATE="$OLD" git -C "$T/repo" commit -q --allow-empty -m old
tx "git commit -m old"
run 0 "a commit older than the session is not counted"
tx "echo \"remember to git commit later\""
run 0 "the words git commit in an echo are not a commit"

git -C "$T/repo" commit -q --allow-empty -m two
fresh; tx "git commit -m two"
run 2 "committed and not pushed: nudged"
grep -qi "push" "$T/err" && echo "OK   nudge says push" || { echo "FAIL nudge says push"; FAIL=$((FAIL+1)); }
run 0 "second stop in a row passes" true
run 0 "a later turn with the same commits is not nudged again"
fresh; EP=sdk-ts tx "git commit -m two"; run 0 "headless runs are not nudged (entrypoint read from the transcript)"
fresh; tx "cd $T/repo && git commit -m two"
run 2 "commit via cd from another cwd is found" false cli "$T"
fresh; tx "git commit -m \"fix push-gate\""
run 2 "push inside a commit message does not count as a push"
fresh; tx "git commit -m two" "git stash push"
run 2 "git stash push does not count as a push"
fresh; tx "git commit -m two" "git push --dry-run"
run 2 "a dry-run push does not count as a push"
fresh; CWD="$T/repo" tx "git commit -m two"
run 2 "commit in a folder reached by an earlier cd is found" false cli "$T"
git clone -q "$T/remote.git" "$T/other" 2>/dev/null
fresh; tx "git commit -m two" "cd $T/other && git push"
run 2 "a push in another repo does not clear this repo's commits"
fresh; tx "git commit -F - <<'EOF'${NL}Now detects (git push) runs${NL}EOF"
run 2 "git push inside a heredoc commit message is not a push"
echo "repo" > "$T/allow"
fresh; tx "git commit -m two"
run 0 "allow-listed repo is not nudged"
: > "$T/allow"
fresh; tx "git commit -m two" "git push"
run 2 "a push in the transcript is not trusted: git still shows unpushed commits"
git -C "$T/repo" push -q 2>/dev/null
fresh; tx "git commit -m two"
run 0 "commit already on the remote: no nudge"
git -C "$T/repo" checkout -q -b gone && git -C "$T/repo" push -q -u origin gone 2>/dev/null
git -C "$T/repo" commit -q --allow-empty -m three
git --git-dir="$T/remote.git" branch -q -D gone && git -C "$T/repo" fetch -q --prune 2>/dev/null
fresh; tx "git commit -m three"
run 0 "upstream branch gone after a merge: no nudge"
rm -r "$T"
echo "failures: $FAIL"; exit $FAIL
