---
disable-model-invocation: true
name: overnight
description: >
  Bedtime sweep. Reads every open Claude terminal in tmux, drafts one /goal per session
  (or a skip with the reason), gets one approval from the user, then types the goals in.
  `/overnight report` gives did/doing/need per session in the morning.
  Triggers: "/overnight", "going to bed", "work overnight", "give them all a goal",
  "message all terminals". Do NOT use for one session going unattended (that is /afk).
metadata:
  user-invocable: true
  slash-command: /overnight
---

# overnight

## Bedtime
1. List targets: `tmux list-sessions -F '#{session_name} #{session_attached} #{pane_current_path}'`
   (PATH needs /opt/homebrew/bin). Keep `cc-*` that are attached. Skip this session.
2. For each, read the pane: `tmux capture-pane -p -t <s> -S -60`. Note: mid-turn, idle,
   waiting on a person, unsent text in the box, over 4h.
3. Draft a table: session, then `Goal: <done state>` or `Skip: <reason>`.
   EVERY session gets a goal. Waiting on a person is not a skip: the goal is to do all the
   work around it (prep, tests, drafts, checks) and list what is left for the user.
   Only unsent text in the box means skip, and tell the user which one.
4. Write each brief to `~/.claude/state/overnight/brief/<session>.md` (task, rules, and
   "write ~/.claude/state/overnight/<tomorrow>/<session>.md with Done tonight and Waiting on
   the user"). Send only the SHORT line `/goal Do ~/.claude/state/overnight/brief/<session>.md`.
   A long line overflows the input box and the helper aborts. Each brief is, a checkable done state, ending with this tail:
   "Local work and commits only. No merge, deploy, outward message or spend. If blocked on
   a person, write it in the handoff and stop."
5. One AskUserQuestion to approve (approve all / edit / cancel). Then for each goal:
   `~/.claude/scripts/tmux-send-line.sh <session> "/goal <line>"`
   Exit 0 sent, 3 skipped (dialog or busy box, never forced), 4 did not land (no Enter sent).
6. After 20s, capture each pane and confirm `/goal active` shows. Report any that do not.
7. Append the table and results to `~/.claude/state/overnight/<YYYY-MM-DD>.md`.

8. Briefs finish in minutes. So every session also gets the open-ended goal in
   `~/.claude/state/overnight/brief/keep-going.md` (met only at 06:30 AND recap current;
   until then work the next useful item). Copy it with tomorrow's date. Then CronCreate a
   re-sweep at :13/:33/:53 from 00:00 to 06:00 that resends it to any session not showing
   "goal active".
9. CronCreate a one-shot around 06:47 that runs `/overnight report` (session-only, so keep
   this session open).

## Morning: `/overnight report`
Read last night's log, capture each goal session's pane, and give per session:
did / doing / need from the user. Three parts only.

## Safety
The helper refuses to type over a dialog or a half-typed line, and sends Enter only after
confirming the text sits in the input box. Never bypass it with raw `tmux send-keys`.
