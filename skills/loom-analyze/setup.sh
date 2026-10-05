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
  # pip3 --user drops the script into python's user-base bin dir, which is
  # NOT on stock macOS's PATH — verify whisper actually resolves before
  # claiming success, otherwise setup "passes" while the skill's own
  # `command -v whisper` gate keeps failing forever.
  if ! command -v whisper >/dev/null; then
    user_base="$(python3 -m site --user-base 2>/dev/null || true)"
    user_bin="$user_base/bin"
    echo "[setup] whisper installed but not found on PATH" >&2
    if [ -x "$user_bin/whisper" ]; then
      echo "[setup] add this to your shell profile (~/.zshrc or ~/.bash_profile), then restart your shell:" >&2
      echo "  export PATH=\"$user_bin:\$PATH\"" >&2
    else
      echo "[setup] expected it at $user_bin/whisper but it's not there either — check the pip3 install output above" >&2
    fi
    exit 3
  fi
  echo "[setup] whisper ok"
else
  echo "[setup] whisper ok"
fi

chmod +x "$(dirname "$0")/loom-analyze.sh"

echo "[setup] done. Try:"
echo "  $(dirname "$0")/loom-analyze.sh <loom-share-url>"
