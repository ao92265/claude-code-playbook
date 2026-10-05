---
name: burn
description: Read your Claude usage momentum: whether you are about to hit the 5 hour or weekly limit, which live session is spending it, and when there is headroom to go back up a model. Explicit invoke only: /burn.
---

# Burn

## What it answers

A percentage on its own is not actionable. 62% is fine at the start of a window
and fatal near the end. This turns it into a rate and a deadline: how fast you
are burning right now, how that compares to a normal hour, and whether you land
over 100% before the window resets.

## Where the numbers come from

Claude Code hands the statusline your real server side quota percentages every
frame and then throws them away. The HUD now keeps one sample a minute in
`~/.claude/usage-history.jsonl`, which is what makes a rate of change possible
at all.

The recorder is `~/.claude/hud/usage-recorder.mjs`, which the HUD calls once a
frame. Six statuslines render at once and all six want to write the same
sample, so the minute is claimed by creating a directory: exactly one process
wins the create and the other five skip. Trimming the file re-reads the tail
before it renames, because anything appended during a naive rewrite is
destroyed by it, and the line destroyed is always the newest one.

These are Anthropic's own figures, not a reconstruction from token counts.
Nothing here converts tokens into a percentage, because the weighting across
models and cache tiers is not published and an invented percentage is worse
than none.

## Running it

    python3 ~/.claude/skills/burn/scripts/burn.py            # human
    python3 ~/.claude/skills/burn/scripts/burn.py --fleet    # and who is spending it
    python3 ~/.claude/skills/burn/scripts/burn.py --json     # machine

Read the output like this:

- **burning X%/h now** is the last 30 minutes inside the current window.
- **Y%/h is normal** is everything burned in the last 24 hours divided by 24,
  idle time included. That is the honest denominator for "is this hour heavy":
  dropping idle hours would make every working hour look average.
- **(N x)** is the two divided. Above 1 means you are accelerating.
- **thin** means the current window is younger than half an hour, so the
  reading is real but built on less evidence than it wants.
- **maybe: best guess N% at reset, too thin to call** means the straight
  reading crosses 100 but the cautious one does not. The percentages arrive as
  whole numbers, so a single step from 94 to 95 over four minutes reads as
  15%/h when the truth is anywhere from nothing to twice that. A breach is only
  declared when it survives handing that rounding back, which is what stops the
  throttle firing on a session that was barely doing anything.
- **estimate: baseline from transcripts** means there is not yet 24 hours of
  recorded history, so the comparison came from transcript token burn instead.
  The ratio is real, the absolute percentage is still the server's.

## Which session is spending it

`--fleet` splits the burn across the sessions that are actually running. The
percentages are account wide and say nothing about who spent them, so the split
comes from the transcripts: every assistant turn records its own token usage.

One session is not one file. A subagent writes its own transcript carrying the
session id of whatever spawned it, so a session that delegates heavily is
spread over several files, and counted per file it appears three times with
every row looking small. The rows are merged by session id, which puts the
delegating session where it belongs, usually at the top. The `subagents`
marker on a row says how much of that spend was delegated work.

The split is by weighted tokens rather than raw ones, using the published price
ratios: output counts five times input, a cache read a tenth. Without that a
session re-reading a large cached prompt sits at the top of the list looking
like the culprit while the session generating real output sits below it.

It is a share of spend, not a share of quota. How the quota weights models and
cache tiers is not published, so the ranking is solid and the absolute split
is an estimate, and it is labelled as one.

## Why the two windows project differently

The 5 hour window projects on your **current** rate. The horizon is at most five
hours, so what you are doing right now is the right predictor.

The 7 day window projects on the **24 hour average**. The horizon is up to seven
days, and a busy half hour says nothing about Thursday. Projecting a weekly cap
off a thirty minute burst would cry breach every single afternoon.

## The way back up

Stepping down is half a policy. If nothing ever says you can afford the big
model again, one busy hour costs the rest of the day, because restoring
`settings.json` only helps the NEXT session and the live one carries on wherever
you left it.

So the same hook offers the way back. When neither window projects a breach and
the tightest of them still has at least twice the room you are using, and the
session is running below your usual, it prints one line telling you what to
type. It never blocks: exit code 2 erases what you typed, and good news is
never worth that.

"Your usual" is learned, not configured. No model name is written down anywhere
here, because a model name in a config file rots. The ceiling is whatever you
were actually running while nothing was throttling you, read from the
transcript rather than from settings, because typing `/model` changes the
session and not the file. A ceiling you have not run in a week is dropped: at
that point it is a decision you have made rather than a downgrade to undo.

At most one offer per session per window, and none at all when the session's
model cannot be read, or when the newest sample is more than five minutes old.
Samples only land while a statusline is rendering, so gaps are normal, and a
stale reading is wrong in the one direction that costs a breach.

## The pane

The HUD stays quiet while you are safe: `5h:62%(2h14m)` is the usual reading,
percentage and time to reset. When the burn rate projects past 100% before the
window resets, the reset time gives way to the more urgent number and it goes
red: `5h:71%!1h18m` means you hit the wall in an hour and eighteen minutes.

## The throttle, and what it genuinely cannot do

Hooks talk through output and exit codes only. They cannot run a slash command,
and `model` and `effortLevel` are read once at session start, so writing them to
settings mid-session does nothing to the session you are already in. There is no
supported way for anything here to change a live session's model or effort.

So detection is automatic and the switch itself is one keystroke:

1. **Projected breach**: the hook blocks the prompt and tells you to type
   `/effort low`. The ladder is per session. The downgrade it writes is account
   wide, but the interruption is not: told once for the whole account, the
   first session to prompt takes the only warning and the five actually
   spending the quota never hear anything. The block also names the session
   doing most of the burning, and says so when that session is the one being
   blocked. Told only the rate, you would have to go and look, and that is the
   step that does not happen. It is worked out only on a prompt that is about
   to be blocked, never on every prompt.
2. **Still projected after 20 minutes**: it blocks once more and tells you to
   type `/model sonnet`. This is the rung that matters, because the limits are
   counted per model family, so changing family is the change that moves the
   number. Effort is the cheap first rung, not the effective one.

At the same time it writes the downgrade into `settings.json`, so any session
you open next starts there already.

Blocking erases your typed prompt, so the hook hands it straight back in the
message and saves it to `~/.claude/burn-last-prompt.txt`.

If putting your settings back fails, it keeps the record rather than clearing
it. That record is the only thing that knows what you were on, so deleting it
after a restore that did not happen would pin you to the small model with
nothing left to explain why. Corrupt settings is what fails that write, not a
read only file: an atomic rename only needs a writable directory.

It also will not record a value it wrote itself as your normal. Two sessions
prompting in the same instant can have the second read settings after the first
downgraded them, and remembering Sonnet as the original is how a busy hour
turns into being on the small model forever.

Four things it will not do:

- Block twice for the same rung in the same window. Maximum two interruptions
  per window, ever.
- Leave you downgraded. The moment the projection clears, or the window resets,
  your original effort and model go back.
- Touch any setting other than those two.
- Survive the off switch: `touch ~/.claude/burn-off` and it stops entirely.

## Tests

    python3 ~/.claude/skills/burn/tests/test_burn.py
    python3 ~/.claude/skills/burn/tests/test_throttle.py
    python3 ~/.claude/skills/burn/tests/test_headroom.py
    python3 ~/.claude/skills/burn/tests/test_fleet.py
    node --test ~/.claude/skills/burn/tests/test_recorder.mjs

Run the fleet tests under a summer timezone too (`TZ=Europe/London`). Transcript
timestamps are UTC, and reading them through local time shifts every session by
the daylight saving offset, which empties the fleet for half the year while
January fixtures stay green.

The reset boundary cases in the first file are the ones that matter. The 5 hour
percentage collapses to near zero every five hours, and a rate computed across
that boundary reads as a large negative burn, which silently inverts the
projection into "you will never run out". Both are written so they fail if the
segmentation is removed.
