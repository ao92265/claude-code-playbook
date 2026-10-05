---
title: Background Jobs
nav_order: 12
parent: Advanced
---
# Background Jobs

Thirteen launchd jobs keep the setup healthy without anyone remembering to run anything. The
scripts are in [`scripts/claude-ops/`](../scripts/claude-ops/) and example plists (label prefix
`com.example.`) in [`scripts/claude-ops/launchd/`](../scripts/claude-ops/launchd/). Headless jobs
that call `claude -p` read a long-lived OAuth token from the macOS keychain at spawn time and pass
it in the environment, never on the command line.

| Job | Schedule | What it does |
|---|---|---|
| run-referee | every 10 min | Watchdog for runaway sessions (see [Session Lifecycle](session-lifecycle.md)) |
| checkpoint | every 15 min | Snapshots every live session's handoff |
| reap | every 30 min | Kills orphaned Claude sessions in detached tmux |
| reauth-watch | every 60 s | Notices when headless auth has genuinely expired, ignores the stale-file false alarm |
| standing-orders | daily 07:10 | Condition and action reminders: runs a probe, has a cheap headless judge decide if the condition fired, notifies |
| pr-review-sweep | daily 07:15 | Reviews open PRs you are asked to review and posts comment-only reviews on your own repos; parks the rest |
| pr-review-check | daily 07:47 | Confirms the sweep actually ran |
| post-merge-digest | daily 07:45 | Summarises review comments on PRs merged since yesterday |
| backup | daily 09:30 | Commits the `~/.claude` config to a private repo |
| maintenance | Mon 09:00 | Rule budget check, hook smoke test, stale file cleanup |
| graveyard | Mon 08:05 | Finds jobs that stopped firing and finished work nobody collected |
| rule-drift-prune | Mon 08:30 | Trims the rule-drift log that measures whether hooks are obeyed |
| memory-consolidate | Tue 08:30 | Merges duplicate memory files and flags stale ones |

## Lessons from running them

- **A log file's timestamp is not proof of life.** A job that exits 0 silently looks healthy for
  weeks. The graveyard sweep checks each job actually fired inside its own period.
- **launchd cannot use AppleScript.** It returns empty and exits 0. Use `lsappinfo` or a CLI.
- **Headless runs inherit your hooks.** A `claude -p` job will hit every gate your interactive
  sessions do. Either design the prompt to pass them or set a marker env var the hooks skip on.
- **Untrusted input means narrow tools.** The PR sweep reads other people's PR text, so its agent
  gets only `gh pr view`, `gh pr diff` and read access to repo checkouts, and its output is scanned
  for credential patterns before anything is posted.
