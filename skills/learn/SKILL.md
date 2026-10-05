---
name: learn
description: Turn logged corrections into hook proposals, but only once a tag hits three strikes. Explicit invoke only: /learn.
---

# /learn

Corrections are already captured. Nothing counts them, so a one-off gripe and a real
pattern look identical, and the rule files only ever grow. This skill is the gate: a tag
has to come up three times before it earns a rule, and anything that never repeats gets
cleared instead of hardening.

## Run the tally first

```
python3 ~/.claude/skills/learn/scripts/tally.py
```

Add `--json` for machine-readable output, `--threshold N` to change the bar. The script
reads `~/.claude/feedback.jsonl` and writes nothing.

It splits tags four ways:

- **PROMOTE** at or above three strikes. These earn a rule.
- **WATCH** under three and still recent. Leave alone. Say nothing about them.
- **PRUNE** under three and untouched for over 30 days. Propose deleting these lines.
- **NEAR-DUPLICATE** tags close enough to be one pattern. Merge before counting, since a
  split tag defeats the threshold.

## The rules of promotion

1. **Three strikes, no fewer.** Two is a coincidence. Do not promote on a hunch that the
   third is coming.
2. **Propose a hook, not prose.** A rule added to CLAUDE.md or an @-imported file stops
   firing once context gets long. Only a hook survives. If the behaviour cannot be caught
   by a hook, say so plainly rather than falling back to prose.
3. **Catch-all tags need a question first.** `wholesale rejection`, `direct contradiction`
   and `told to stop doing something` are what the detector assigns when it cannot
   classify. A high count there measures how often the user pushed back, not one behaviour.
   Before proposing anything, read the sessions behind those entries and find the actual
   repeated behaviour, or ask him which one he means. Never promote the bucket itself.
4. **One rule per run, at most two.** The point is to stop rule sprawl, not to add four
   hooks in an afternoon.
5. **Check it is not already covered.** Grep the existing hooks first. `register-gate.py`,
   `answer-shape-nudge.sh` and `prose-guard.sh` between them already cover register,
   answer shape and prose tells.

## What to hand back

For each promoted tag:

- The tag, its count, and the dates it spans.
- One line on the behaviour, in plain English, quoting one real example from the log.
- The proposed hook: which event it binds to, what it checks, and what it says when it
  fires. Ten lines of pseudocode at most.
- Whether an existing hook should be extended instead of adding a new one. Extending is
  almost always the right answer.

Then the prune list, as a plain list of lines to delete, and nothing else.

## Boundaries

This skill proposes. It does not edit `~/.claude/hooks/**`, `settings.json`, or any rule
file, and it does not rewrite `feedback.jsonl`. the user approves each change, then the edit
happens as normal work with `hooks-smoke-test.sh` run afterwards.
