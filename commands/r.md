---
description: Resume the last handoff and carry on with the outstanding work
argument-hint: "[optional: a filename fragment to pick an older handoff]"
allowed-tools: Bash, Read, Grep, Glob
---

Resume work from a handoff and CONTINUE it. This is not a status report.

## 1. Pick the handoff

Run the picker. It never guesses across sessions:

```
~/.claude/scripts/resume-pick.sh "$ARGUMENTS"
```

With a fragment it takes the newest filename match. Without one it takes the newest
reboot whose `- Session:` line belongs to THIS session's name. If it prints nothing,
say so with its stderr reason and ask which handoff, do NOT fall back to the newest.
Read the whole file. Also read any handover doc it points at.

## 2. Verify before trusting it

A handoff records what a previous session believed, not what is true now. Before
acting, confirm the branch, the working tree state and anything it claims is
running. A claim in a handoff is a lead, not a fact.

## 3. Continue

Find what is still outstanding and build it. Sources, in order:

- the handoff's own next-intent or remaining-work section
- any handover or plan document it points at, especially sections headed
  "remaining", "outstanding", "left undone", "open", "to fix next"
- the branch's own uncommitted or half-finished work

Split what you find into two piles:

- **Buildable now**: a clear defect or a stated next task with a known fix.
  Do these. Follow the branch's own house rules if the handoff lists any.
- **Needs a ruling from the user**: anything where the fix depends on a product
  decision nobody has made. Do NOT decide these silently. Collect them and ask
  at the end, as one short list.

If the handoff explicitly says the work is finished and to stop, respect that,
but still check the documents it points at for outstanding items before
concluding there is nothing to do.

## 4. Report

Lead with what you built. End with the rulings you need, if any.
