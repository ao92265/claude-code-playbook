#!/bin/bash
# paste-guard.py: prompts holding credentials or card numbers are blocked with a sanitized clipboard copy.
source "$(dirname "$0")/lib.sh"
H="$HOOKS_DIR/paste-guard.py"
BIN="$TD/bin"; mkdir -p "$BIN"
printf '#!/bin/sh\ncat > "%s/clip"\n' "$TD" > "$BIN/pbcopy"; chmod +x "$BIN/pbcopy"
pg() { # <stdin> [args...]
  local in="$1"; shift
  printf '%s' "$in" | env PATH="$BIN:$PATH" "$@" >"$TD/o" 2>"$TD/e"; RC=$?; OUT=$(cat "$TD/o"); ERR=$(cat "$TD/e")
}
hook() { local in="$1"; shift; pg "$in" env "$@" python3 "$H"; }
P() { jq -nc --arg p "$1" '{hook_event_name:"UserPromptSubmit",prompt:$p}'; }
# fake credentials built at runtime so no literal key sits in this file
AWS="AKIA$(printf 'A%.0s' $(seq 16))"
ANT="sk-ant-$(printf 'x%.0s' $(seq 30))"

hook "$(P "deploy with $AWS now")";            expect "aws key exits 0" 0
expect_has "blocks the prompt" "$OUT" '"decision": "block"'
expect_has "names the finding" "$OUT" "AWS Access Key"
expect_lacks "never echoes the value" "$OUT" "$AWS"
expect_has "clipboard holds sanitized text" "$(cat "$TD/clip" 2>/dev/null)" "[REDACTED:AWS Access Key]"
expect_lacks "clipboard has no secret" "$(cat "$TD/clip" 2>/dev/null)" "$AWS"
hook "$(P "key $ANT")"
expect_has "anthropic key caught" "$OUT" "Anthropic API Key"
hook "$(P 'pay with 4111 1111 1111 1111 please')"
expect_has "luhn-valid card caught" "$OUT" "Payment Card"
hook "$(P 'order number 4111 1111 1111 1112 please')"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   luhn-invalid number passes"; } || { fail=$((fail+1)); echo "FAIL luhn-invalid number passes"; }
hook "$(P 'mail bob@elsewhere.org about it')"
expect_has "outside email caught" "$OUT" "Email"
hook "$(P 'mail bob@example-corp.com about it')"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   allowlisted email passes"; } || { fail=$((fail+1)); echo "FAIL allowlisted email passes"; }
hook "$(P 'refactor the parser please')"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   clean prompt silent"; } || { fail=$((fail+1)); echo "FAIL clean prompt silent"; }
hook "$(P "!!raw $AWS")"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   !!raw bypass passes"; } || { fail=$((fail+1)); echo "FAIL !!raw bypass passes"; }
hook "$(P "$AWS")" PASTE_GUARD_DISABLED=1
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   disable env passes"; } || { fail=$((fail+1)); echo "FAIL disable env passes"; }
mkdir -p "$HOME/.claude/state/paste-guard"; touch "$HOME/.claude/state/paste-guard/off"
hook "$(P "$AWS")"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   off state file passes"; } || { fail=$((fail+1)); echo "FAIL off state file passes"; }
rm "$HOME/.claude/state/paste-guard/off"
hook 'not json';                               expect "bad json exits 0" 0
hook "$(jq -nc --arg p "$AWS" '{hook_event_name:"Stop",prompt:$p}')"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   other event ignored"; } || { fail=$((fail+1)); echo "FAIL other event ignored"; }
[[ -s "$HOME/.claude/logs/paste-guard.jsonl" ]] && { pass=$((pass+1)); echo "ok   event logged"; } || { fail=$((fail+1)); echo "FAIL event logged"; }
expect_lacks "log has no secret" "$(cat "$HOME/.claude/logs/paste-guard.jsonl")" "$AWS"

# wrapped fragment after a redaction is swept
FRAG="$(printf 'abcdefgh%.0s' 1 2 3)"
hook "$(P "$(printf 'token %s\n%s\nend' "$ANT" "$FRAG")")"
expect_has "wrapped fragment swept" "$(cat "$TD/clip")" "[REDACTED:Token Fragment]"

# sanitize mode
pg "use $AWS here" python3 "$H" --sanitize;    expect "sanitize exits 1 when redacted" 1
expect_has "sanitize redacts" "$OUT" "[REDACTED:AWS Access Key]"
pg "plain text" python3 "$H" --sanitize;       expect "sanitize clean exits 0" 0
expect_has "sanitize passes clean text" "$OUT" "plain text"
pg "!!raw $AWS" python3 "$H" --sanitize;       expect "sanitize bypass exits 0" 0
pg "$(printf 'fine\nuse %s\nfine' "$AWS")" python3 "$H" --scan-lines
expect_has "scan-lines flags line 2" "$OUT" "2"
finish
