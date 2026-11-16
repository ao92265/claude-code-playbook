#!/bin/bash
# matcha-review.sh (zsh): sends a mid-sized new diff to the Matcha runner once, under a daily cap.
# The runner is a local stub, so nothing leaves the machine.
source "$(dirname "$0")/lib.sh"
command -v zsh >/dev/null || { echo "skip: no zsh"; exit 0; }
H=matcha-review.sh
REPO="$TD/repo"; mkdir -p "$REPO"; git -C "$REPO" init -q
git -C "$REPO" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
TOP=$(git -C "$REPO" rev-parse --show-toplevel)
KEY=$(printf '%s' "$TOP" | shasum | cut -c1-12)
STATE="$HOME/.claude/.matcha-review"
CALLS="$TD/calls"
mkdir -p "$HOME/.claude/skills/matcha"
mkdir -p "$HOME/.claude"
cat > "$HOME/.claude/skills/matcha/matcha-run.sh" <<EOF
#!/bin/bash
echo call >> "$CALLS"
echo "VERDICT stub"
EOF
chmod +x "$HOME/.claude/skills/matcha/matcha-run.sh"

zrun() { (cd "$REPO" && env "$@" zsh "$HOOKS_DIR/$H" </dev/null >/dev/null 2>&1); RC=$?; sleep 1; }
calls() { if [[ -f "$CALLS" ]]; then wc -l < "$CALLS" | tr -d ' '; else echo 0; fi; }

seq 1 30 > "$REPO/optin.txt"; git -C "$REPO" add optin.txt
zrun
[[ $(calls) == 0 ]] && RC=0 || RC=1;                    expect "repo not on the allow list is not sent" 0
git -C "$REPO" reset -q; rm -f "$REPO/optin.txt"
printf '%s\n' "$TOP" > "$HOME/.claude/matcha-review.allow"

printf 'a\nb\n' > "$REPO/small.txt"; git -C "$REPO" add small.txt
zrun;                                                   expect "small diff exits 0" 0
[[ $(calls) == 0 ]] && RC=0 || RC=1;                    expect "small diff is not sent" 0

seq 1 30 > "$REPO/big.txt"; git -C "$REPO" add big.txt
zrun;                                                   expect "big diff exits 0" 0
[[ $(calls) == 1 ]] && RC=0 || RC=1;                    expect "big diff is sent once" 0
expect_has "findings saved for the surface hook" "$(cat "$STATE/$KEY.findings" 2>/dev/null)" "VERDICT stub"

zrun
[[ $(calls) == 1 ]] && RC=0 || RC=1;                    expect "same diff is not sent again" 0

seq 1 31 > "$REPO/big.txt"
zrun CLAUDE_SKIP_HOOKS=matcha
[[ $(calls) == 1 ]] && RC=0 || RC=1;                    expect "skip switch honoured" 0

zrun MATCHA_REVIEW_DAILY_MAX=1
[[ $(calls) == 1 ]] && RC=0 || RC=1;                    expect "daily cap stops a second send" 0

zrun
[[ $(calls) == 2 ]] && RC=0 || RC=1;                    expect "changed diff under the cap is sent" 0

{ seq 1 30; echo 'api_key = "abcdefghijklmnop1234567890"'; } > "$REPO/leak.txt"; git -C "$REPO" add leak.txt
zrun
[[ $(calls) == 2 ]] && RC=0 || RC=1;                    expect "diff holding a secret is not sent" 0
git -C "$REPO" reset -q; rm -f "$REPO/leak.txt"

(cd "$TD" && zsh "$HOOKS_DIR/$H" </dev/null >/dev/null 2>&1); RC=$?
expect "outside a repo exits 0" 0
[[ $(calls) == 2 ]] && RC=0 || RC=1;                    expect "outside a repo nothing is sent" 0
cat > "$HOME/.claude/skills/matcha/matcha-run.sh" <<EOF
#!/bin/bash
echo call >> "$CALLS"
exit 1
EOF
seq 1 40 > "$REPO/fail.txt"; git -C "$REPO" add fail.txt
zrun
[[ $(calls) == 3 ]] && RC=0 || RC=1;                    expect "failing run is sent" 0
[[ -f "$STATE/$KEY.hash" ]] && RC=1 || RC=0;            expect "failed run clears the mark" 0
zrun
[[ $(calls) == 4 ]] && RC=0 || RC=1;                    expect "failed diff is retried on the next stop" 0
finish
