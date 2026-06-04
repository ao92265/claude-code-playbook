# loom-analyze (Claude Code skill)

Turn a Loom share URL into a transcript (and optional keyframes) locally — no API key, no third-party MCP.

## Install

1. Copy this entire folder to `${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/skills/loom-analyze/` on the target machine.
2. Run the one-time setup:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/skills/loom-analyze/setup.sh
   ```
   Installs Homebrew packages `yt-dlp` + `ffmpeg` and pip package `openai-whisper`.
3. Restart Claude Code. The skill is auto-discovered from the `SKILL.md` frontmatter.

## Use

Inside Claude Code, paste any `https://www.loom.com/share/...` URL or say:
- "transcribe this loom <url>"
- "analyze this loom <url>"
- "/loom-analyze <url>"

Claude will call the shell wrapper and inline the transcript.

Direct CLI use:
```bash
${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/skills/loom-analyze/loom-analyze.sh <URL>                 # transcript only
${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/skills/loom-analyze/loom-analyze.sh <URL> --frames 10     # +PNG every 10s
${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/skills/loom-analyze/loom-analyze.sh <URL> --model small   # better accuracy
${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/skills/loom-analyze/loom-analyze.sh <URL> --keep          # don't delete MP3/MP4
```

Output: `~/Downloads/loom-transcripts/<id>/`
- `audio.txt` — transcript
- `frames/frame-NNNN.png` — keyframes (when `--frames` used)

## Requirements

- macOS (or Linux with Homebrew). Windows + WSL works the same.
- Python 3 (for whisper).
- ~140 MB disk for the `base` whisper model (downloaded on first run); `small` ~460 MB; `medium` ~1.5 GB; `large` ~3 GB.

## Troubleshooting

- **"Missing dep" error:** re-run `setup.sh`.
- **`whisper` not found after install:** ensure `~/Library/Python/3.x/bin` (or wherever pip user-installs binaries) is on PATH.
- **Loom URL not recognised:** must be `loom.com/share/<id>`. Embedded/private links won't work without auth.

## What it does NOT do

- No streaming / real-time. Whole-video transcription only.
- No speaker diarization (single transcript stream).
- No upload to any third-party service. All processing is local.
