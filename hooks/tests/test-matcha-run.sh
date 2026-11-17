#!/bin/bash
# matcha-run.sh (zsh): write mode may edit files but must never get a shell,
# because the delegate's environment holds the gateway key.
# Fake security, stat and claude commands, so nothing leaves the machine.
source "$(dirname "$0")/lib.sh"
command -v zsh >/dev/null || { echo "skip: no zsh"; exit 0; }
RUNNER="$HOOKS_DIR/../skills/matcha/matcha-run.sh"
BIN="$TD/bin"; mkdir -p "$BIN" "$TD/work"
ARGS="$TD/claude-args"

cat > "$BIN/security" <<'EOF'
#!/bin/bash
echo fake-key
EOF
cat > "$BIN/stat" <<'EOF'
#!/bin/bash
date +%s
EOF
cat > "$BIN/claude" <<EOF
#!/bin/bash
printf '%s\n' "\$@" > "$ARGS"
echo '{"result":"stub done","total_cost_usd":0,"num_turns":1,"is_error":false}'
EOF
chmod +x "$BIN"/*

mkdir -p "$HOME/.claude"
echo 'MATCHA_BASE_URL=http://127.0.0.1:9' > "$HOME/.claude/matcha.env"
echo '{"data":[{"id":"claude-opus-9"},{"id":"claude-haiku-9"}]}' > "$HOME/.claude/.matcha-models.json"

mrun() { (cd "$TD/work" && env PATH="$BIN:$PATH" TMPDIR="$TD" zsh "$RUNNER" --dir "$TD/work" "$@" >"$TD/out" 2>"$TD/err"); RC=$?; }
tools() { grep -A1 -x -- '--tools' "$ARGS" | tail -1; }

mrun "read task"
expect "read-only run exits 0" 0
[[ "$(tools)" == "Read,Grep,Glob" ]] && RC=0 || RC=1;         expect "read-only run gets read tools only" 0

rm -f "$ARGS"
mrun --write "write task"
expect "write run exits 0" 0
[[ "$(tools)" == *Edit* && "$(tools)" == *Write* ]] && RC=0 || RC=1; expect "write run can edit files" 0
[[ "$(tools)" == "Read,Grep,Glob,Edit,Write" ]] && RC=0 || RC=1; expect "write run gets exactly the edit tools, no shell" 0
grep -qx -- '--restricted' "$ARGS" && grep -qx -- '--strict-mcp-config' "$ARGS" && RC=0 || RC=1
expect "write run keeps restricted and strict MCP flags" 0
finish
