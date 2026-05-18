#!/usr/bin/env bash
# loom-analyze — Download a Loom video and produce:
#   1. Audio transcript (via whisper)
#   2. (optional) Keyframes every N seconds for visual analysis
#
# Usage:
#   loom-analyze <loom-share-url> [--model base|small|medium|large] [--frames N] [--keep]
#
# Output dir: ~/Downloads/loom-transcripts/<id>/
#   audio.txt   transcript
#   frames/     PNG screenshots (when --frames given)
#
# Deps: yt-dlp, ffmpeg, openai-whisper

set -euo pipefail

URL="${1:-}"
MODEL="base"
FRAMES=0
KEEP=0

if [[ -z "$URL" ]]; then
  cat >&2 <<EOF
Usage: loom-analyze <loom-share-url> [--model M] [--frames N] [--keep]
  --model M    whisper model: base (default), small, medium, large
  --frames N   also extract one PNG every N seconds (skips if omitted)
  --keep       keep audio + video files after transcription
EOF
  exit 1
fi
shift || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)  MODEL="$2"; shift 2 ;;
    --frames) FRAMES="$2"; shift 2 ;;
    --keep)   KEEP=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ ! "$URL" =~ loom\.com ]]; then
  echo "Not a loom.com URL: $URL" >&2
  exit 1
fi

for bin in yt-dlp ffmpeg whisper; do
  if ! command -v "$bin" >/dev/null; then
    echo "Missing dep: $bin — run setup.sh in this skill folder" >&2
    exit 2
  fi
done

ID="$(echo "$URL" | sed -E 's#.*/share/([a-zA-Z0-9]+).*#\1#')"
OUT_DIR="$HOME/Downloads/loom-transcripts/$ID"
mkdir -p "$OUT_DIR"

echo "[loom-analyze] id=$ID model=$MODEL frames=$FRAMES" >&2

if [[ "$FRAMES" -gt 0 ]]; then
  echo "[loom-analyze] downloading video..." >&2
  yt-dlp -q --no-warnings -f 'best[ext=mp4]/best' \
    -o "$OUT_DIR/video.%(ext)s" "$URL" >&2
  VIDEO="$(ls "$OUT_DIR"/video.* 2>/dev/null | head -1)"
  if [[ -z "$VIDEO" ]]; then
    echo "[loom-analyze] video download failed" >&2
    exit 3
  fi
  echo "[loom-analyze] extracting audio..." >&2
  ffmpeg -y -loglevel error -i "$VIDEO" -vn -acodec libmp3lame "$OUT_DIR/audio.mp3" >&2
  echo "[loom-analyze] extracting frames every ${FRAMES}s..." >&2
  mkdir -p "$OUT_DIR/frames"
  ffmpeg -y -loglevel error -i "$VIDEO" -vf "fps=1/${FRAMES}" "$OUT_DIR/frames/frame-%04d.png" >&2
  echo "[loom-analyze] frames saved to $OUT_DIR/frames/" >&2
else
  echo "[loom-analyze] downloading audio only..." >&2
  yt-dlp -q --no-warnings -f 'bestaudio/best' \
    -x --audio-format mp3 \
    -o "$OUT_DIR/audio.%(ext)s" "$URL" >&2
fi

AUDIO="$OUT_DIR/audio.mp3"
if [[ ! -f "$AUDIO" ]]; then
  echo "[loom-analyze] audio missing" >&2
  exit 4
fi

echo "[loom-analyze] transcribing (whisper $MODEL)..." >&2
whisper "$AUDIO" \
  --model "$MODEL" \
  --output_dir "$OUT_DIR" \
  --output_format txt \
  --language en \
  --verbose False >&2 2>/dev/null || {
    echo "[loom-analyze] whisper failed" >&2
    exit 5
  }

TXT="$OUT_DIR/audio.txt"
if [[ ! -f "$TXT" ]]; then
  echo "[loom-analyze] whisper produced no .txt" >&2
  exit 6
fi

echo "[loom-analyze] done" >&2
echo "[loom-analyze] transcript: $TXT" >&2
[[ "$FRAMES" -gt 0 ]] && echo "[loom-analyze] frames:     $OUT_DIR/frames/" >&2
echo "" >&2
cat "$TXT"

if [[ "$KEEP" -eq 0 ]]; then
  rm -f "$AUDIO" "$OUT_DIR"/video.* 2>/dev/null || true
fi
