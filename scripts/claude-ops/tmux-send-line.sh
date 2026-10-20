#!/usr/bin/env bash
# tmux-send-line.sh <tmux-target> <text>
#
# Types one line into a Claude Code session running in tmux, then Enter, using
# the same two guards as session-rotate.sh (read that header for the why):
#   1. Before typing: no dialog on screen, input box present and EMPTY.
#   2. After typing, before Enter: the text is exactly what sits in the box.
# Enter on a dialog is an approval, so any doubt means stop and send nothing.
#
# Exit: 0 sent · 3 skipped (dialog, busy box, no box) · 4 typed but did not land
set -uo pipefail
PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
PANE="${1:?target}"; TEXT="${2:?text}"

DIALOG_RE='enter to confirm|enter to select|esc to cancel|do you want to|would you like to|no, and tell claude|yes, and (don.t ask|auto-accept)|select an option|trust this folder|quick safety check|\[y/n\]|\(y/n\)'

pane_text() {
  tmux capture-pane -p -e -t "$PANE" 2>/dev/null \
    | perl -pe 's/\e\[2m.*?\e\[0m//g; s/\e\[[0-9;?]*[A-Za-z]//g' | tr -d '\r'
}
has_inputbox() {
  printf '%s' "$1" | awk -v nb="$(printf '\302\240')" '
    { line[NR] = $0 }
    END {
      for (i = 2; i < NR; i++) {
        if (line[i] ~ /^❯/ && line[i-1] ~ /^──/ && line[i+1] ~ /^─────/) {
          s = line[i]; sub(/^❯/, "", s); gsub(nb, " ", s); gsub(/[ \t]/, "", s)
          if (s == "") { exit 0 }; exit 2
        }
      }
      exit 1
    }'
}
landed() {
  local want have
  want=$(printf '%s' "$1" | perl -CS -pe 's/[\s\x{a0}]//g')
  have=$(pane_text | perl -CS -ne '
    BEGIN { $in = 0; $prev = ""; $box = ""; $found = 0 }
    chomp;
    if ($in) { if (/^\x{2500}{5}/) { $in = 0; $found++ } else { $box .= $_ } }
    elsif (/^\x{276f}/ && $prev =~ /^\x{2500}{2}/) { $in = 1; ($box = $_) =~ s/^\x{276f}//; }
    $prev = $_;
    END { $box =~ s/[\s\x{a0}]//g; print $box if $found == 1 && !$in }')
  [ -n "$want" ] && [ "$have" = "$want" ]
}

SCREEN=$(pane_text)
[ -n "$SCREEN" ] || { echo "skip: pane empty or gone"; exit 3; }
printf '%s' "$SCREEN" | grep -qiE "$DIALOG_RE" && { echo "skip: dialog on screen"; exit 3; }
has_inputbox "$SCREEN"; BOX=$?
[ "$BOX" = 1 ] && { echo "skip: no input box"; exit 3; }
[ "$BOX" = 2 ] && { echo "skip: text already in the box"; exit 3; }

tmux send-keys -t "$PANE" -l "$TEXT" || exit 4
sleep 1
landed "$TEXT" || { echo "abort: text did not land, sent no Enter"; exit 4; }
tmux send-keys -t "$PANE" Enter || exit 4
echo "sent"
