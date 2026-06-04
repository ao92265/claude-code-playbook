#!/bin/bash
# Simple TTS wrapper for Claude Code

VOICE_FILE="$HOME/.claude/tts-voice.txt"
VOLUME_FILE="$HOME/.claude/tts-volume.txt"
DISABLED_FILE="$HOME/.claude/tts-disabled"
PIPER="$HOME/.local/bin/piper"
VOICE_DIR="$HOME/.claude/piper-voices"

# Check if disabled
[ -f "$DISABLED_FILE" ] && exit 0

# Read voice config
VOICE=$(cat "$VOICE_FILE" 2>/dev/null || echo "en_US-lessac-medium")
VOLUME=$(cat "$VOLUME_FILE" 2>/dev/null || echo "0.1")

MODEL="$VOICE_DIR/${VOICE}.onnx"
[ ! -f "$MODEL" ] && exit 1

# Get text from argument or stdin
TEXT="${1:-$(cat)}"
[ -z "$TEXT" ] && exit 0

# Speak it using afplay (background, non-blocking)
TMP_FILE="/tmp/claude-tts-$$.wav"
echo "$TEXT" | "$PIPER" --model "$MODEL" --output_file "$TMP_FILE" 2>/dev/null && \
  afplay -v "$VOLUME" "$TMP_FILE" 2>/dev/null && rm -f "$TMP_FILE" &
