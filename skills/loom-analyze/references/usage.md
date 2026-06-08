# loom-analyze — requirements & troubleshooting

Detail split out of SKILL.md per progressive disclosure. Read this only when setup fails or the user hits a limitation.

## Install (per-machine, one-time)

1. Copy this entire folder to `${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/skills/loom-analyze/` on the target machine.
2. Run setup: `bash ${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/skills/loom-analyze/setup.sh` — installs Homebrew packages `yt-dlp` + `ffmpeg` and pip package `openai-whisper`. Idempotent.
3. Restart Claude Code. The skill is auto-discovered from the `SKILL.md` frontmatter.

## Requirements

- macOS (or Linux with Homebrew). Windows + WSL works the same.
- Python 3 (for whisper).
- Disk for the whisper model, downloaded on first run: `base` ~140 MB, `small` ~460 MB, `medium` ~1.5 GB, `large` ~3 GB.

## Troubleshooting

- **"Missing dep" error:** re-run `setup.sh`.
- **`whisper` not found after install:** ensure `~/Library/Python/3.x/bin` (or wherever pip user-installs binaries) is on PATH.
- **Loom URL not recognised:** must be `loom.com/share/{id}`. Embedded/private links won't work without auth.

## What it does NOT do

- No streaming / real-time. Whole-video transcription only.
- No speaker diarization (single transcript stream).
- No upload to any third-party service. All processing is local.
