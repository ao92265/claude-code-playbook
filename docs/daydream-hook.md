---
title: Daydream Hook
nav_order: 43
parent: Hooks
---
# Daydream Hook — Idle-Time Memory Recombination

A `Stop` hook that turns idle time into ideas. When you finish a turn and go quiet, it spawns a detached, headless `claude` that samples your persistent memory, recombines two or three entries into scored ideas, logs them, and — if the best one clears a bar — forges a quick PRD. A companion `SessionStart` hook shows you what it came up with the next time you open a session.

This is a [Gwern-style "daydreaming loop"](https://gwern.net/ai-daydreaming): the value isn't in any single memory, it's in the connections between them that you never sat down to draw. The machine has idle cycles and a list of your own notes; this points one at the other.

It is deliberately cheap and bounded: at most one daydream per day, at most one PRD per day.

---

## When You Want This

- You keep a persistent memory / notes corpus (project ideas, spikes, blockers, content angles) that's richer than any one session uses.
- You'd rather wake up to a few scored ideas than start every session from a blank page.
- You already run a planning skill (this pairs with [prdforge](skills-ecosystem.md) — the daydream promotes its best idea straight into a quick PRD).

When you don't want it: you have no memory corpus to draw on, you're on metered API billing where background runs cost real money (see [Auth](#authentication-the-one-real-gotcha)), or you're not on macOS (the token store below uses the macOS keychain).

---

## How It Works

```
Stop (you go idle)
  └─ daydream.sh
       ├─ skip if: DAYDREAM_CHILD set (recursion guard) | killswitch | <24h since last
       ├─ read OAuth token from keychain → if absent, stay dormant + leave a hint
       ├─ write the daily sentinel, then spawn DETACHED:
       │
       └─ claude --print  (DAYDREAM_CHILD=1, token via env)
             ├─ sample 2–3 memories (varied by run, deduped against a ledger)
             ├─ recombine → 1–3 ideas, score novelty × value × actionability
             ├─ append all ideas → daydreams/journal-YYYY-MM.md
             ├─ if top score ≥ 0.70 (and no PRD yet today): /prdforge "<idea>" --quick
             └─ write a one-liner → daydreams/digest-pending.md

Next SessionStart
  └─ daydream-surface.sh → prints the pending digest once, then archives it
```

The engine's behaviour lives in a prompt, not in code — see [`hooks/daydream-engine-prompt.md`](https://github.com/ao92265/claude-code-playbook/blob/main/hooks/daydream-engine-prompt.md). Edit that file to change how it samples, scores, or what bar it uses for promotion.

---

## Authentication: the one real gotcha

A freshly-spawned `claude` process can't reuse the running app's credentials. You need a long-lived token for it, and **you must not use `--bare`**:

- `--bare` skips hooks (which is what you'd reach for to avoid the child re-triggering its own Stop hook) — **but it also skips auth resolution**, so the token is ignored and the run dies with `Not logged in`. This is the trap; it fails silently in the background.
- The working recipe is plain `--print` with the token in the environment, full settings loaded (so skills and plugin agents still resolve), and the child's hooks tamed by env instead: `DAYDREAM_CHILD=1` (blocks recursion), and — if you run a hook layer that honours them — flags to quiet it.

Set it up once:

```bash
# 1. Mint a long-lived token (on your Claude subscription, valid ~1 year)
claude setup-token

# 2. Store it in the macOS keychain — NOT in any file. -w with no value
#    prompts hidden, so the token never lands in shell history.
security add-generic-password -U -a "$USER" -s daydream-oauth -w
```

Never paste the token into a file that gets committed or backed up. The hook reads it from the keychain at spawn time and passes it via the environment (never on the command line, so it can't be seen in `ps`).

Verify without leaking it — the token stays inside a command substitution:

```bash
CLAUDE_CODE_OAUTH_TOKEN="$(security find-generic-password -a "$USER" -s daydream-oauth -w)" \
  claude --print -p "reply with exactly: auth-ok"
```

Until a token exists, the hook stays dormant (no daily slot burned) and leaves a one-line activation hint in the digest.

---

## Install

```bash
# scripts
cp hooks/daydream.sh hooks/daydream-surface.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/daydream*.sh

# the engine prompt the hook reads
mkdir -p ~/.claude/daydreams
cp hooks/daydream-engine-prompt.md ~/.claude/daydreams/engine-prompt.md
# then edit it: set <your-home-slug> to your home dir with / → - (e.g. -Users-jane)
```

Register in `~/.claude/settings.json` — append to the existing arrays, don't replace them:

```json
{
  "hooks": {
    "Stop": [
      { "matcher": "", "hooks": [
        { "type": "command", "command": "~/.claude/hooks/daydream.sh", "timeout": 5 }
      ]}
    ],
    "SessionStart": [
      { "matcher": "", "hooks": [
        { "type": "command", "command": "~/.claude/hooks/daydream-surface.sh", "timeout": 5 }
      ]}
    ]
  }
}
```

The daydream needs a memory corpus to draw on: `daydream.sh` looks for `MEMORY.md` in your home-project auto-memory dir and exits quietly if it isn't there.

---

## Cost & Safety

| Guard | Mechanism |
|-------|-----------|
| ≤ 1 daydream / day | `state/daydream-last.ts` sentinel, written *before* the spawn so a crash can't refire |
| ≤ 1 PRD / day | separate `state/daydream-prdforge-last.ts` sentinel |
| No fork-bomb | child sets `DAYDREAM_CHILD=1`; the hook short-circuits when it sees it |
| Never blocks your session | detached `nohup … &`, stdin redirect, returns in well under a second |
| Stays out of git | child runs in `~/.claude/daydreams`, writes only there |
| Cheap model | child and its subagents pinned to a mid-tier model; PRD runs in `--quick` mode |

Worst-case background spend is one cheap pass plus at most one quick PRD per day.

**Disable:** remove the two entries from `settings.json`, or set a killswitch env var your hook layer honours (the script checks `OMC_SKIP_HOOKS=daydream` and `DISABLE_OMC`). Removing the keychain token also makes it dormant.

---

## Why a Prompt, Not Code

The recombination logic — which memories to favour, how to score, when to promote — is judgement, not control flow. Keeping it in [`daydream-engine-prompt.md`](https://github.com/ao92265/claude-code-playbook/blob/main/hooks/daydream-engine-prompt.md) means you tune it in plain language without touching the hook. The hook is just plumbing: rate-limit, authenticate, spawn, get out of the way.
