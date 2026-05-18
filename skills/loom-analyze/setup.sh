#!/usr/bin/env bash
# One-time setup for loom-analyze skill.
# Installs yt-dlp, ffmpeg, openai-whisper.
# Safe to re-run; skips anything already installed.

set -euo pipefail

echo "[setup] checking deps..."

if ! command -v brew >/dev/null; then
  echo "[setup] Homebrew not installed. Install from https://brew.sh first." >&2
  exit 1
fi

if ! command -v yt-dlp >/dev/null; then
  echo "[setup] installing yt-dlp..."
  brew install yt-dlp
else
  echo "[setup] yt-dlp ok"
fi

if ! command -v ffmpeg >/dev/null; then
  echo "[setup] installing ffmpeg..."
  brew install ffmpeg
else
  echo "[setup] ffmpeg ok"
fi

if ! command -v whisper >/dev/null; then
  echo "[setup] installing openai-whisper (pip3)..."
  if command -v pip3 >/dev/null; then
    pip3 install --user --upgrade openai-whisper
  else
    echo "[setup] pip3 missing — install Python 3 first" >&2
    exit 2
  fi
else
  echo "[setup] whisper ok"
fi

chmod +x "$(dirname "$0")/loom-analyze.sh"

echo "[setup] done. Try:"
echo "  $(dirname "$0")/loom-analyze.sh <loom-share-url>"
