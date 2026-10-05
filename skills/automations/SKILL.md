---
disable-model-invocation: true
name: automations
description: >
  Single registry view + management for scheduled Claude automations — the Codex
  "Automations" tab equivalent over this machine's launchd jobs. Use when the user
  says "/automations", "list my automations", "what's scheduled", "what cron jobs do
  I have", "add a scheduled task", or "when did <job> last run". Wraps the existing
  com.example.claude-* launchd daemons (morning, observatory, maintenance, reauth);
  does NOT replace them. Do NOT use for /loop or /goal in-session loops (those are
  ephemeral, not scheduled jobs).
metadata:
  user-invocable: true
  slash-command: /automations
  proactive: false
---

# automations

A registry over the user's scheduled Claude work. The daemons already run via
macOS launchd; this skill makes them *visible and manageable* from one place.

## Subcommands

### `list` (default)
Run `~/.claude/scripts/automations-list.sh`. Prints a table: label · cadence ·
last run (log mtime) · status. Also flags active crontab lines. Read-only.

### `inspect <label>`
Tail the job's log to see recent output:
`tail -n 40 ~/.claude/logs/com.example.claude-<label>.log`
(launchd stderr is the separate `*.launchd.log`.) Use this when `status` shows
`empty` or a run looks wrong.

### `add`
Scaffold a NEW scheduled job. Steps:
1. Gather: short name, the script under `~/.claude/scripts/` to run, and the
   schedule (hour/minute, or weekdays).
2. Copy `~/.claude/skills/automations/assets/template.plist` to
   `~/Library/LaunchAgents/com.example.claude-<name>.plist`, substituting
   `__NAME__`, `__SCRIPT__`, `__HOUR__`, `__MINUTE__` (add more
   `StartCalendarInterval` dict entries for multiple weekdays — mirror
   `com.example.claude-morning.plist`).
3. **Confirm with the user before loading** — never auto-load. Then:
   `launchctl load ~/Library/LaunchAgents/com.example.claude-<name>.plist`
4. Verify: re-run `list` and confirm the new label appears.

> Scheduling a recurring autonomous Claude run is outward-facing and recurring —
> always confirm cadence + command with the user before `launchctl load`.

## Notes

- Cadence parsing: `StartInterval` → "every Ns"; `StartCalendarInterval` →
  "calendar (N entries)" (one entry per fire time, e.g. 5 weekday mornings).
- "Last run" = mtime of `~/.claude/logs/com.example.claude-<label>.log`, the
  app log the job appends to (not the launchd wrapper log).
- Known jobs at time of authoring: `morning`, `observatory`, `maintenance`,
  `reauth-watch`.

## Related

- `~/.claude/scripts/automations-list.sh` — the lister this wraps.
- `/loop`, `/goal` — in-session recurring/objective work (not launchd-scheduled).
