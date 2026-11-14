#!/bin/bash
# matcha-surface.sh (zsh): delivers an unseen Matcha review once, and warns when usage is high.
source "$(dirname "$0")/lib.sh"
command -v zsh >/dev/null || { echo "skip: no zsh"; exit 0; }
H=matcha-surface.sh
REPO="$TD/repo"; mkdir -p "$REPO"; git -C "$REPO" init -q
TOP=$(git -C "$REPO" rev-parse --show-toplevel)
KEY=$(printf '%s' "$TOP" | shasum | cut -c1-12)
STATE="$HOME/.claude/.matcha-review"; mkdir -p "$STATE"

zrun() { OUT=$(cd "$REPO" && env "$@" zsh "$HOOKS_DIR/$H" </dev/null 2>/dev/null); RC=$?; }

zrun;                                                   expect "nothing pending exits 0" 0
expect_lacks "nothing pending prints nothing" "$OUT" "MATCHA"

printf 'VERDICT risky\n- empty input crashes\n' > "$STATE/$KEY.findings"
zrun;                                                   expect "findings exit 0" 0
expect_has "delivers the review" "$OUT" "MATCHA SECOND REVIEW"
expect_has "includes the bullets" "$OUT" "empty input crashes"
zrun
expect_lacks "delivers only once" "$OUT" "empty input crashes"

sleep 1; echo CLEAN > "$STATE/$KEY.findings"
zrun
expect_lacks "a CLEAN review stays quiet" "$OUT" "MATCHA SECOND REVIEW"

sleep 1; echo 'VERDICT x' > "$STATE/$KEY.findings"
zrun CLAUDE_SKIP_HOOKS=matcha
expect_lacks "skip switch honoured" "$OUT" "MATCHA"

U="$HOME/.claude/usage-history.jsonl"
echo '{"five_hour":{"used_percentage":40},"seven_day":{"used_percentage":95}}' > "$U"
zrun
expect_has "warns at 95 percent of the week" "$OUT" "MATCHA OFFLOAD"
echo '{"five_hour":{"used_percentage":99},"seven_day":{"used_percentage":50}}' > "$U"
zrun
expect_has "arms takeover at 99 percent" "$OUT" "MATCHA TAKEOVER ARMED"
echo '{"five_hour":{"used_percentage":10},"seven_day":{"used_percentage":20}}' > "$U"
zrun
expect_lacks "quiet at low usage" "$OUT" "MATCHA OFFLOAD"
echo '{"five_hour":{"used_percentage":99},"seven_day":{"used_percentage":99}}' > "$U"
touch -t 202001010000 "$U"
zrun
expect_lacks "ignores a stale usage file" "$OUT" "MATCHA TAKEOVER"
finish
