#!/bin/bash
# Stop hook: earn coins based on tokens spent this turn, shown in a
# dedicated Terminal window (coin-window.sh), not written into the live
# Claude Code pane. Writing straight into that pane corrupted its render or
# typed into the input box, so the payoff lives in its own window instead.

input=$(cat 2>/dev/null || true)
transcript=$(printf '%s' "$input" | python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('transcript_path',''))" 2>/dev/null || true)

# slot-machine analogy: tokens fed IN (prompt, incl. cache) vs coins paid
# OUT (completion), not one blended number
tokens_in=0
tokens_out=0
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  read -r tokens_in tokens_out < <(tail -n 40 "$transcript" 2>/dev/null | python3 -c "
import json, sys
usage = None
for line in sys.stdin:
    try:
        d = json.loads(line)
        u = d.get('message', {}).get('usage')
        if u:
            usage = u
    except Exception:
        pass
if usage:
    fed_in = (usage.get('input_tokens', 0)
              + usage.get('cache_read_input_tokens', 0)
              + usage.get('cache_creation_input_tokens', 0))
    paid_out = usage.get('output_tokens', 0)
    print(fed_in, paid_out)
else:
    print(0, 0)
" 2>/dev/null || echo "0 0")
fi

case "$tokens_in" in ''|*[!0-9]*) tokens_in=0 ;; esac
case "$tokens_out" in ''|*[!0-9]*) tokens_out=0 ;; esac

coins=$tokens_out
[ "$coins" -lt 1 ] && coins=1
tokens=$tokens_in

SOUND_DIR="$HOME/.claude/hooks/sounds"
sounds=("$SOUND_DIR"/*.mp3)
pick="${sounds[$RANDOM % ${#sounds[@]}]}"
if command -v afplay >/dev/null 2>&1 && [ -f "$pick" ]; then
  afplay "$pick" >/dev/null 2>&1 &
fi

python3 "$HOME/.claude/hooks/coin-bank.py" "$coins" "$tokens" >/dev/null 2>&1

if ! pgrep -f "coin-window.sh" >/dev/null 2>&1; then
  # split the CURRENT iTerm window into a side pane instead of a new
  # floating window, so it can be dragged/arranged like any other pane
  osascript -e '
    tell application "iTerm"
      activate
      tell current window
        tell current session
          set newSession to (split vertically with default profile)
        end tell
        tell newSession
          write text "~/.claude/hooks/coin-window.sh"
        end tell
      end tell
    end tell
  ' >/dev/null 2>&1 &
fi

exit 0
