---
name: loom-analyze
description: Download a Loom video share URL and produce an audio transcript (whisper) plus optional keyframes for visual analysis. Triggers on any loom.com share URL the user provides, or on phrases "transcribe this loom", "analyze this loom", "watch this loom", "/loom-analyze <url>".
---

# Loom Analyze

Local pipeline (no API key, no third-party MCP) that turns a Loom share URL into:

1. A plain-text transcript via `whisper`.
2. Optional keyframe PNGs for visual analysis when the user asks about UI / screen content.

## When to invoke

- User pastes a `https://www.loom.com/share/...` URL.
- User says "transcribe", "analyze", or "watch this loom".
- `/loom-analyze <url>` is typed.

## How to run

The shell wrapper lives next to this file: `loom-analyze.sh`. Always call it through Bash.

```bash
${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/skills/loom-analyze/loom-analyze.sh <URL> [--model M] [--frames N] [--keep]
```

Flags:

- `--model base|small|medium|large` — whisper accuracy/speed tradeoff. Default `base` (~140 MB download first time).
- `--frames N` — also extract one PNG every N seconds into `frames/`. Skip this for transcript-only (faster).
- `--keep` — keep MP4/MP3 after transcribing. Default deletes them.

Output goes to `~/Downloads/loom-transcripts/<id>/`. The transcript is printed to stdout, so the agent gets it in the tool result.

## Decision rules for the agent

- **Transcript-only is the fast default.** Don't request frames unless the user asks about visuals, UI, screen content, or a demo walkthrough.
- **Long videos (>10 min):** stick to `--model base`. `--model small` or larger only when the user specifically complains about transcript accuracy.
- **When frames are extracted:** read the PNGs from `~/Downloads/loom-transcripts/<id>/frames/` via the Read tool when the user asks what's on screen at a given time. Don't bulk-read every frame; pick the ones that match the question.
- **First-time setup:** if the script exits with "Missing dep", run `${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/skills/loom-analyze/setup.sh` once, then retry.

## Setup (per-machine, one-time)

```bash
bash ${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/skills/loom-analyze/setup.sh
```

Installs `yt-dlp`, `ffmpeg`, `openai-whisper` via Homebrew + pip. Idempotent.
