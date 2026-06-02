# Session Handoff — automatic park/resume for many parallel sessions

If you run several Claude Code terminals at once and leave them open overnight,
the next morning is painful: each session is huge, `claude --resume` reloads the
*entire* transcript (so the resumed session is already near its context limit and
degraded), and you reread everything to remember where you were.

This is a small, hook-based system that fixes it. The core idea:

> **Don't resume a bloated session. Park a compact handoff, then start a _fresh_
> session that reads it.** A 40-line handoff beats a 6 MB transcript every time.

It also closes a real Claude Code gap: auto-compaction fires mid-thought at ~95%
context and silently drops start-of-session rules, architecture rationale, and
your next steps. The `PreCompact` hook snapshots that the instant before it's lost.

## Pieces

| File | Hook | What it does | Cost |
|------|------|--------------|------|
| `stop-handoff.sh` | `Stop` | Overwrites a compact live handoff (branch, dirty files, last 3 asks, last action) after every turn | free (git + jq) |
| `precompact-handoff.sh` | `PreCompact` | Appends a richer snapshot (all files edited, full ask history) just before compaction | free; optional non-blocking LLM via `HANDOFF_LLM=1` |
| `sessionstart-handoff.sh` | `SessionStart` | Injects the saved handoff into a fresh session's context (skips on `--resume`) | free |
| `tools/morning.sh` + `/morning` skill | — | One briefing across **all** parked sessions | free |
| `/handoff` skill (existing) | — | Curated, human-authored `SESSION_NOTES.md` on demand | one LLM turn |

## Where state lives

A central store, **not** your repo, so worktrees stay clean (no git-status noise,
no accidental commits) and `/morning` can scan everything at once:

```
$CLAUDE_CONFIG_DIR/handoffs/<repo-slug>.md          # live, overwritten each turn
$CLAUDE_CONFIG_DIR/handoffs/<repo-slug>.compact.md  # preserved pre-compaction snapshots
```

`<repo-slug>` is the working directory with `/`→`-` (e.g. `Users-me-Repos-Wraith`),
so each worktree gets its own file.

## Install

```bash
# 1. copy the hooks where Claude Code can run them
cp hooks/{stop,precompact,sessionstart}-handoff.sh ~/.claude/hooks/
cp tools/morning.sh ~/.claude/scripts/
chmod +x ~/.claude/hooks/*-handoff.sh ~/.claude/scripts/morning.sh

# 2. wire them in ~/.claude/settings.json (add to the "hooks" object):
```

```jsonc
{
  "hooks": {
    "SessionStart": [
      { "matcher": "", "hooks": [
        { "type": "command", "command": "~/.claude/hooks/sessionstart-handoff.sh", "timeout": 10 } ] }
    ],
    "PreCompact": [
      { "matcher": "", "hooks": [
        { "type": "command", "command": "~/.claude/hooks/precompact-handoff.sh", "timeout": 20 } ] }
    ],
    "Stop": [
      { "matcher": "", "hooks": [
        { "type": "command", "command": "~/.claude/hooks/stop-handoff.sh", "timeout": 15 } ] }
    ]
  }
}
```

(If you already have `Stop` hooks, append this one to the existing array rather
than replacing it.)

## Requirements

- `jq` (transcript parsing)
- `git` (state) — handoffs still write for non-git dirs, just without branch info
- `gh` (optional, for the PR section of `/morning`)

## Notes & limits

- Handoffs are **machine-written and may be slightly stale** — always verify
  `git status`/branch in the worktree before acting. The `SessionStart` injection
  ends with that reminder.
- The `Stop` hook runs every turn; it's intentionally deterministic (no LLM) so it
  can't slow you down or run up cost. LLM enrichment is opt-in (`HANDOFF_LLM=1`)
  and runs in the background on `PreCompact` only.
- Old handoffs (>14 days) are ignored by `SessionStart` so abandoned worktrees
  don't inject noise. The files are tiny; prune `~/.claude/handoffs/` whenever.
