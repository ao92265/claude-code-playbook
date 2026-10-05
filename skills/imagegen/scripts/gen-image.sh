#!/bin/zsh
# gen-image.sh - generate or edit an image via Gemini on the ParentCo Matcha gateway.
#
# Usage:
#   gen-image.sh [-m MODEL] [-a ASPECT] [-i INPUT_IMAGE] -o OUT.png "prompt"
#
#   -m  gemini-3.1-flash-image (default) or gemini-2.5-flash-image
#   -a  1:1 (default), 4:3, 3:4, 16:9, 9:16
#   -i  an existing image to edit; may be repeated for multiple references
#   -o  output path (required)
#
# Prints the saved path on success. Non-zero exit with a message on failure.
set -e
CFG="$HOME/.claude/matcha.env"
[[ -r "$CFG" ]] || { print -u2 "imagegen: missing $CFG (run the Matcha setup first)"; exit 1; }
source "$CFG"
KEY="$(security find-generic-password -a "$USER" -s matcha-api-key -w 2>/dev/null)" \
  || { print -u2 "imagegen: key not in keychain (service: matcha-api-key)"; exit 1; }

MODEL="gemini-3.1-flash-image"
ASPECT="1:1"
OUT=""
typeset -a INPUTS
while getopts "m:a:i:o:" opt; do
  case $opt in
    m) MODEL="$OPTARG" ;;
    a) ASPECT="$OPTARG" ;;
    i) INPUTS+=("$OPTARG") ;;
    o) OUT="$OPTARG" ;;
    *) print -u2 "imagegen: bad flag"; exit 1 ;;
  esac
done
shift $((OPTIND-1))
PROMPT="$*"
[[ -n "$OUT" ]]    || { print -u2 "imagegen: -o output path is required"; exit 1; }
[[ -n "$PROMPT" ]] || { print -u2 "imagegen: no prompt given"; exit 1; }

# Gemini image models sit behind the Gemini passthrough, not the Anthropic one.
GEM_BASE="${MATCHA_BASE_URL%/anthropic}/gemini"

HERE="${0:A:h}"

REQ="$(python3 "$HERE/_build_request.py" "$ASPECT" "$PROMPT" "${INPUTS[@]}")"

# ${MODEL} needs the braces: zsh would read $MODEL:g as a history modifier.
RESP="$(printf '%s' "$REQ" | curl -s -m 180 \
  "$GEM_BASE/v1beta/models/${MODEL}:generateContent" \
  -H "MATCHA-API-KEY: $KEY" -H "content-type: application/json" -d @-)"

printf '%s' "$RESP" | python3 "$HERE/_save_image.py" "$OUT"
