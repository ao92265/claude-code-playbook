---
title: The "upgrade your CLAUDE.md" carousel, field-tested
parent: Prompting & Discipline
grand_parent: News & Research
nav_order: 6
permalink: /docs/news/carousel-audit-field-test/
---
# The "upgrade your CLAUDE.md" carousel, field-tested against a 117-skill setup

**Source:** @CodeWithAltin, "Upgrade your CLAUDE.md / Audit + rebuild your skills / Turn your build into a plan" (LinkedIn/X carousel, July 2026)

The pitch: three prompts to run while a frontier model is cheap, so the mid-tier models you'll pay for afterwards inherit a setup good enough to carry them. Prompt 1 audits your CLAUDE.md against the real project. Prompt 2 audits your skills folder. Prompt 3 converts a build into a plan a cheaper model executes solo.

Carousel advice usually evaporates on contact with a real setup. This one mostly didn't. I ran all three against a long-accreted config: 5 CLAUDE.md layers, 42 hooks, 117 entries in the skills namespace. The one change I made to the prompts was making the model bring evidence from 2,390 logged sessions instead of opinions.

## What prompt 1 found (CLAUDE.md audit)

Six rules were prose duplicates of hooks. A rule that a PreToolUse hook already enforces mechanically is dead weight in every prompt. Deleted the prose, kept the hooks.

One rule was factually wrong. The file claimed "no hook catches CRLF churn". A hook added later did exactly that. Nobody re-audits old rules against new hooks; the prompt did.

The stalest line was the model line. "Main loop runs Opus 4.8" — written in June, false by July. Model facts rot fastest. The fix is date-robust wording, not a newer hardcoded fact.

And one rule failed its own test. My config says "rule ignored 3 sessions → delete or hook-ify". A rule mandating a skill "at the start of every session" had fired once in 2,390 sessions. It did not survive its own policy.

## What prompt 2 found (skills audit)

This is the carousel's "folder nobody fixes" claim, and it held up embarrassingly well.

95 of 117 namespace entries had zero invocations in six weeks. 40 of them were dangling symlinks: a machine migration copied the links but not the directory they pointed at. Two were referenced by name in my design rules and had been failing silently for two days.

The most damning number: a verification skill that bundles typecheck + lint + tests + build existed and was invoked zero times, while those same commands were run manually, one by one, in 327 of 2,390 sessions. The skill wasn't missing. Its trigger phrases matched sentences nobody says.

The right response turned out to be deletion, not creation. Every hand-repeated workflow already had a skill that wasn't firing. The verdict pass ended at 68 live skills: 13 archived, 3 merges (one 1,524-line skill folded into a 198-line replacement), 4 trigger rewrites, 0 new skills.

## What prompt 3 is actually worth

The plan-for-a-cheaper-model format (objective, model-verifiable success checklist, milestones, small tasks with per-task done-checks, handoff notes) is a decent spec. It doesn't need to be a new skill or a fresh prompt each time, though. I folded it into an existing planning skill as an output flag. If your planner already emits a PRD, this is a renderer on top of it, not a methodology.

## Where the carousel oversells

"So Opus or Sonnet keep hitting near-Fable quality" — a cleaner CLAUDE.md removes stale facts and contradictions; it does not upgrade a model tier. Expect fewer wrong turns, not higher ceilings.

The prompts also assume the model can see usage data. Without session logs to grep, prompt 2 degenerates into the model guessing which skills look unused. The evidence layer is what made this audit land, and the carousel never mentions it.

Credit where due: prompt 1's "flag every rule that's only there because I fill it in from my head" is the best line in the set. It's also the hardest to execute without an explicit test. Mine was: would the model do this anyway? If yes, delete.

## Run it yourself

1. Give the audit prompt real usage evidence: session logs, hook inventory, invocation counts. Not just the files.
2. Cross-reference every CLAUDE.md rule against your hooks first. Prose that a hook enforces is free deletion.
3. In the skills pass, fix triggers before writing new skills. Unused-but-existing beats new-and-also-unused.
4. Check your symlinks after any machine migration. Backups store links, not what they point to.

Verdict: worth running, with receipts. The prompts are ordinary; the forcing function is real — audit the setup while the strong model is free, and make the result legible to the weaker ones. Final numbers: user-owned rule lines 117→120 (six dead rules out, one falsehood fixed, two new blocks in), skills namespace 117→68, and one 0-versus-327 finding that no prompt cleverness would have surfaced without logs.
