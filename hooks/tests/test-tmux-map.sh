#!/bin/bash
# tmux-map.sh: SessionStart records which tmux pane a session lives in; outside tmux it records nothing;
# entries whose pane is gone are pruned. tmux is a stub.
source "$(dirname "$0")/lib.sh"
H=tmux-map.sh
CFG="$HOME/.claude"; mkdir -p "$CFG"; ln -s "$HOOKS_DIR" "$CFG/hooks"
MAP="$CFG/state/tmux-map"
mkdir -p "$TD/bin"
cat > "$TD/bin/tmux" <<'STUB'
#!/bin/bash
case "$1" in
  display-message) echo "my-tmux-session" ;;
  list-panes) printf '%%5\n%%6\n' ;;
esac
STUB
chmod +x "$TD/bin/tmux"
PATHX="PATH=$TD/bin:$PATH"
P='{"session_id":"sid-1","transcript_path":"/t/x.jsonl","cwd":"/work/dir"}'
check() { if eval "$2"; then pass=$((pass+1)); echo "ok   $1"; else fail=$((fail+1)); echo "FAIL $1"; fi; }

run tmux-map.sh "$P" "$PATHX" TMUX= TMUX_PANE=%5;          expect "outside tmux exits 0" 0
check "outside tmux records nothing" '[[ ! -e "$MAP/sid-1.json" ]]'
run tmux-map.sh "$P" "$PATHX" TMUX=/tmp/sock,123,0; expect "no pane exits 0" 0
check "no pane id records nothing" '[[ ! -e "$MAP/sid-1.json" ]]'

mkdir -p "$MAP"
echo '{"session":"old","pane":"%9"}' > "$MAP/old.json"
echo '{"session":"live","pane":"%6"}' > "$MAP/live.json"
run tmux-map.sh "$P" "$PATHX" TMUX=/tmp/sock,123,0 TMUX_PANE=%5; expect "in tmux exits 0" 0
J="$MAP/sid-1.json"
check "map file written" '[[ -s "$J" ]]'
check "pane recorded" '[[ "$(jq -r .pane "$J")" == "%5" ]]'
check "socket recorded" '[[ "$(jq -r .socket "$J")" == "/tmp/sock" ]]'
check "tmux session name recorded" '[[ "$(jq -r .tmux_session "$J")" == "my-tmux-session" ]]'
check "cwd and transcript recorded" '[[ "$(jq -r .cwd "$J")" == "/work/dir" && "$(jq -r .transcript "$J")" == "/t/x.jsonl" ]]'
check "dead-pane entry pruned" '[[ ! -e "$MAP/old.json" ]]'
check "live-pane entry kept" '[[ -e "$MAP/live.json" ]]'
run tmux-map.sh '{"cwd":"/x"}' "$PATHX" TMUX=/tmp/sock,123,0 TMUX_PANE=%5; expect "missing session id exits 0" 0
run tmux-map.sh "$P" "$PATHX" TMUX=/tmp/sock,123,0 TMUX_PANE=%7 CLAUDE_SKIP_HOOKS=tmux-map
check "skip env records nothing" '[[ "$(jq -r .pane "$J")" == "%5" ]]'
finish
