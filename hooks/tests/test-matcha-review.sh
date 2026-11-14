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
mkdir -p "$HOME/.claude/scripts"
cat > "$HOME/.claude/scripts/matcha-run.sh" <<EOF
#!/bin/bash
echo call >> "$CALLS"
echo "VERDICT stub"
EOF
chmod +x "$HOME/.claude/scripts/matcha-run.sh"

zrun() { (cd "$REPO" && env "$@" zsh "$HOOKS_DIR/$H" </dev/null >/dev/null 2>&1); RC=$?; sleep 1; }
calls() { if [[ -f "$CALLS" ]]; then wc -l < "$CALLS" | tr -d ' '; else echo 0; fi; }

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

(cd "$TD" && zsh "$HOOKS_DIR/$H" </dev/null >/dev/null 2>&1); RC=$?
expect "outside a repo exits 0" 0
finish
