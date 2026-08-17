---
title: Superpowers
nav_order: 8
parent: Advanced
---
# Superpowers

A plugin that gives Claude a process: ask before building, plan in small pieces, write the test
first, debug systematically, verify before claiming done. It is in Anthropic's own marketplace,
sourced from [obra/superpowers](https://github.com/obra/superpowers).

```bash
claude plugin install superpowers@claude-plugins-official
```

Active from your next session. There is nothing to type.

---

## How it actually fires

A session-start hook injects one instruction: check for a relevant skill before doing anything,
and if one applies, use it. Fourteen skills sit behind that, loaded only when they fire.

You will see it announce itself, in the form *"Using test-driven-development to..."*. That is the
tell that it engaged. If you never see that line, it did not.

| Trigger | Skill that fires |
|---|---|
| "let's build X" | brainstorming, then writing-plans |
| "fix this bug" | systematic-debugging |
| Any code change | test-driven-development |
| Before claiming done | verification-before-completion |
| A plan with many independent tasks | subagent-driven-development |

## What it costs

About 584 tokens on every session, then 500 to 8,000 each time a skill actually fires. The
session-start hook itself is free: it runs in the harness, not in the model's context.

Check any plugin's cost before installing it:

```bash
claude plugin details <name>@<marketplace>
```

## What the measurement showed

Two arms, same prompt, same starting repo: build a small CLI end to end with tests passing.

| | With superpowers | Without |
|---|---|---|
| Wall clock | 5m 13s | 9m 13s |
| Cost | $1.82 | $1.91 |
| Tests written | 55 | 66 |
| Order of work | test first, every layer | all source first, tests after |
| Repair loop | 4 edits | 10 edits |

Both shipped working code and both told the truth about being done. The interesting part is not
the speed, it is one specific moment: the plugin arm ran its first test, saw it fail, and then
noticed the failure was the test runner rather than the missing module. It moved the
implementation aside, proved a real failure, and only then wrote the fix.

**That is the habit worth having, with or without the plugin.** A test that has only ever failed
because of an import error has never once guarded the behaviour it claims to.

## Where it will fight your setup

It describes its workflows as mandatory and tells the model it has no choice. If you already run
your own rules, expect friction in three places:

1. **Planning.** It wants to brainstorm before plan mode. If you have your own planning skill,
   say which one wins, in your rules, before you need to decide mid-task.
2. **Verification.** Its verification skill will declare work done. If you have a stricter gate
   (a typecheck-lint-test-build command, or an independent review), keep that as the real gate
   and let the skill be the first pass.
3. **Tone.** It asks the model to announce every skill invocation. If you have hard rules about
   reply length or register, say so once rather than fighting it every turn.

Its own instructions defer to your CLAUDE.md, which is the lever: one short section naming what
wins settles all three.

```markdown
<superpowers>
Its skills are advisory here, not mandatory: these rules win where they disagree.
Use its test-first loop and its systematic debugging. Do not let its brainstorming
replace your planning skill, or its verification replace your completion gate.
</superpowers>
```

## Turning it off

```bash
claude plugin disable superpowers@claude-plugins-official   # keep it installed, stop it firing
claude plugin uninstall superpowers@claude-plugins-official # remove it
```

## When it is worth it

Worth installing if your sessions drift: work starts before the requirements are clear, tests get
written after the code, "done" arrives without evidence. It supplies discipline you have not built
yet.

Less worth it if you already have that discipline enforced somewhere it cannot be argued with, in
hooks or gates. Then you are paying for a second copy of your own rules, in a voice that insists it
outranks them.
