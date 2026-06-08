#!/bin/bash
# TTS notification hook for Claude Code
# Uses Piper for high-quality voice, falls back to macOS say
# Respects AgentVibes mute state: /agent-vibes:mute to silence, /agent-vibes:unmute to restore

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/notification.conf"
MUTE_FILE="$HOME/.claude/tts-mute"
PIPER_MODEL="$HOME/.local/share/piper/voices/en_GB-alan-medium.onnx"
PIPER_BIN="$HOME/.local/bin/piper"

# Check mute state (AgentVibes compatible)
if [ -f "$MUTE_FILE" ]; then
  exit 0
fi

MODE="voice"
SOUND_PATH="/System/Library/Sounds/Glass.aiff"

if [ -f "$CONFIG_FILE" ]; then
    while IFS='=' read -r key value; do
        case "$key" in
            mode) MODE="$value" ;;
            sound_path) SOUND_PATH="$value" ;;
        esac
    done < "$CONFIG_FILE"
fi

# Read hook metadata from stdin
INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')

if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    exit 0
fi

# Extract the last assistant message text from the JSONL transcript
CONTENT=$(jq -s -r '
    [.[] | select(.type == "assistant")] | last |
    .message.content |
    if type == "array" then
        map(select(.type == "text") | .text) | join("\n")
    elif type == "string" then
        .
    else
        empty
    end
' "$TRANSCRIPT_PATH")

# Look for last Summary: line (case insensitive)
SUMMARY=$(echo "$CONTENT" | grep -i "^Summary:" | tail -1 | sed 's/^[Ss]ummary:[[:space:]]*//')

if [ -n "$SUMMARY" ]; then
    if [ "$MODE" = "bell" ]; then
        if [ -f "$SOUND_PATH" ]; then
            afplay "$SOUND_PATH"
        else
            afplay /System/Library/Sounds/Glass.aiff
        fi
    elif [ -x "$PIPER_BIN" ] && [ -f "$PIPER_MODEL" ]; then
        # Use Piper for high-quality TTS
        TMP_WAV=$(mktemp /tmp/piper-notify-XXXX.wav)
        echo "$SUMMARY" | "$PIPER_BIN" --model "$PIPER_MODEL" --output-file "$TMP_WAV" 2>/dev/null
        if [ -f "$TMP_WAV" ] && [ -s "$TMP_WAV" ]; then
            afplay "$TMP_WAV"
        fi
        rm -f "$TMP_WAV"
    else
        # Fallback to macOS say
        say "$SUMMARY"
    fi
fi
