#!/bin/bash
# tmux-name-sync.sh: renames the tmux session to match the Claude session name (sanitized, de-duplicated);
# ignores placeholder names. tmux is a stub; never blocks.
source "$(dirname "$0")/lib.sh"
H=tmux-name-sync.sh
mkdir -p "$TD/bin" "$HOME/.claude/sessions"
cat > "$TD/bin/tmux" <<STUB
#!/bin/bash
case "\$1" in
  display-message) case "\$3" in *session_name*) cat "$TD/cur" ;; *pane_pid*) echo 4242 ;; esac ;;
  has-session) grep -qx "\${3#=}" "$TD/existing" ;;
  rename-session) echo "\$3 \$4" >> "$TD/renames" ;;
esac
STUB
chmod +x "$TD/bin/tmux"
PATHX="PATH=$TD/bin:$PATH"
: > "$TD/existing"
setup() { echo "$1" > "$TD/cur"; printf '{"pid":4242,"name":"%s"}\n' "$2" > "$HOME/.claude/sessions/4242.json"; : > "$TD/renames"; }
go() { run $H '' "$PATHX" TMUX=/tmp/s,1,0 "$@"; }
check() { if eval "$2"; then pass=$((pass+1)); echo "ok   $1"; else fail=$((fail+1)); echo "FAIL $1"; fi; }

setup cc-you-3 chatbot
go;                                       expect "rename run exits 0" 0
check "renamed to the claude name" '[[ "$(cat "$TD/renames")" == "cc-you-3 chatbot" ]]'
setup cc-you-3 "my.proj:x y"
go
check "unsafe characters sanitized" '[[ "$(cat "$TD/renames")" == "cc-you-3 my-proj-xy" ]]'
setup cc-you-3 chatbot; echo chatbot > "$TD/existing"
go
check "name collision gets a suffix" '[[ "$(cat "$TD/renames")" == "cc-you-3 chatbot-2" ]]'
setup chatbot chatbot; : > "$TD/existing"
go
check "already matching is not renamed" '[[ ! -s "$TD/renames" ]]'
setup cc-you-3 you-a0
go
check "placeholder name ignored" '[[ ! -s "$TD/renames" ]]'
setup cc-you-3 chatbot
run $H "" "$PATHX" TMUX=;                expect "outside tmux exits 0" 0
check "outside tmux renames nothing" '[[ ! -s "$TD/renames" ]]'
setup cc-you-3 chatbot
go CLAUDE_SKIP_HOOKS=other,tmux-name-sync
check "skip list honoured" '[[ ! -s "$TD/renames" ]]'
go CLAUDE_SKIP_HOOKS=unrelated
check "unrelated skip entry does not disable it" '[[ -s "$TD/renames" ]]'
finish
