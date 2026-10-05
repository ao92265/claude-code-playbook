#!/bin/bash
# Long-running watcher for the coin-rain minigame. Runs in its own Terminal
# window (opened by coin-rain.sh), polls the shared state file, and redraws
# a coin total whenever it changes. Never runs inside a Claude Code pane.
STATE="$HOME/.claude/hooks/coin-state.json"
last_mtime=0

clear
echo "🪙  COIN BANK  🪙"
echo "Watching for winnings..."

while true; do
  if [ -f "$STATE" ]; then
    mtime=$(stat -f '%m' "$STATE" 2>/dev/null || echo 0)
    if [ "$mtime" != "$last_mtime" ]; then
      last_mtime=$mtime
      read -r total earned fed_in total_fed_in < <(python3 -c "
import json
d = json.load(open('$STATE'))
print(d.get('total',0), d.get('last_earned',0), d.get('last_fed_in',0), d.get('total_fed_in',0))
" 2>/dev/null || echo "0 0 0 0")
      clear
      echo "🪙  COIN BANK  🪙  (fed in vs paid out, like a slot machine)"
      echo
      row=""
      show=$earned
      [ "$show" -gt 30 ] && show=30
      for ((i = 0; i < show; i++)); do row+="🪙"; done
      [ -n "$row" ] && printf '%s\n\n' "$row"
      echo "fed in:  $fed_in tokens"
      echo "paid out: $earned coins"
      echo
      echo "LIFETIME: fed in $total_fed_in tokens, paid out $total coins"
    fi
  fi
  sleep 1
done
