---
title: Opus 4.7 launch-day reactions
parent: Models & Vendors
grand_parent: News & Research
nav_order: 3
---
# Opus 4.7 Released! — Community Launch-Day Reactions

**Source:** r/ClaudeCode, [u/awfulalexey — "Opus 4.7 Released!"](https://www.reddit.com/r/ClaudeCode/comments/1sn5943/opus_47_released/) (posted ~20h before 2026-04-17 extraction, roughly 16 April evening UTC — same day 4.7 was announced)

## Key takeaways

- **Usage limits hit dramatically faster** than on 4.6 — multiple Max-plan users report 5-hour limits burning 20-70% in a single plan + execute cycle.
- **Knowledge cutoff regression:** 4.7 is Jan 2025, 4.6 was May 2025. No official explanation.
- **Per-file-read malware system reminder** leaks into visible output on code-analysis sessions — a real token tax.
- `/model claude-opus-4-7[1m]` confirmed for the 1M-context variant.
- `aLionChris` posted the cleanest operational cheat-sheet for developers — worth bookmarking.
- Community sentiment is openly skeptical about perceived "nerf on release" patterns.

## OP's summary (what Anthropic announced)

- Better at complex programming tasks; stronger than 4.6 especially on difficult and lengthy tasks; follows instructions better; checks its own answers more frequently.
- Improved vision/multimodality — higher-resolution image support (dense screenshots, diagrams, precise visual work).
- Higher-quality output for work materials — interfaces, slides, documents look more polished.
- **Same per-token price as 4.6:** $5/M input, $25/M output.
- Availability: Claude products, API, Amazon Bedrock, Google Vertex AI, Microsoft Foundry.

## Community sentiment — skeptical and cost-conscious

### Top-voted reactions

- *"the fuck"* — polacrilex67 & _BreakingGood_ (145 and 53 upvotes respectively)
- **TriggerHydrant:** *"alright, get your hard work in now before it degrades in 2 months when 4.8 hits"* (116 upvotes)
- **Temporary-Mix8022:** *"2 weeks*"* — running joke about nerf acceleration
- **9gxa05s8fa8sh:** *"SAME PRICE EXCEPT IT COSTS MORE HAHAHAHAHA"*
- **TheGoldenBunny93:** *"Opus 4.7 = 4.6 from january with new makeup."*
- **arvidurs:** *"I mean yes - degrade 4.6 then release 4.7 claim it's stronger than 4.6. And then just release the initial 4.6 under 4.7 name."*
- **somerussianbear:** *"Every release they just re-release the release notes"*

### Usage-limit field reports

- **gorgono95:** *"I did two prompts. First one to analyse and create a plan. Second one to execute. My 5h limit went from 24% to 72%. 5x plan btw."*
- **THE-ROUNDSQUARE:** *"opened two terminals one prompt in each, 12 minutes later one warning... you are at 91% of your daily quota, niceeee, really nice"*
- **pakalumachito:** *"don't forget it uses 35% more token while reducing overall plan usage limit"*

### The "car wash test" regression

- **ketosoy:** *"I'm pleased to report that it is already failing the car wash test."* (OG community informal regression test)
- **HelicopterVivid6154:** *"The OG test"*
- **samueldgutierrez:** *"Fails the car wash test... rushes to answer with that new adaptive thinking... sigh"*

### Model-identification bug (resolved quickly)

- **Smart_Tiger_7106:** *"The first question I asked it was 'what advantages does opus 4.7 offer over 4.6' to which it replied 'Opus 4.6 doesn't exist, if you meant Opus 4.5 ...' — i had to screenshot the Opus 4.6 option as a proof for it... then it came back saying its system message is faulty and not updated..."*

### Knowledge cutoff oddity

- **Soft_Table_8892:** *"Interesting it says knowledge cutoff is Jan 2025 for 4.7 yet may 2025 for 4.6."*

Multiple commenters noted 4.7's knowledge cutoff is **Jan 2025**, yet 4.6's was **May 2025** — i.e. 4.7 is trained on an *older* cutoff than its predecessor. No official explanation in-thread.

## The system-reminder leak (important operational finding)

**OldSausage** reports:

> "When I asked Opus 4.7 to check an issue in a codebase (the prompt said nothing about malware), its first response was: *'This file is clearly not malware — it's a standard Vue 3 enquiry edit form for a job management system, with normal CRUD operations (load/save enquiry, cancel, close, convert to job). I'll proceed with the requested fix.'*"

"When I asked it why malware was so top of mind it replied: *'That comment came from a system reminder injected into the tool results when I read the file. The reminder told me to consider whether each file I read could be malware, and to refuse to improve or augment it if so (but still allowed analysis). So I wasn't independently flagging concerns about your code — I was responding to that automated prompt before proceeding with the edit.'*"

On the cost: *"Yeah, that's a fair frustration. The reminder fires on every file read regardless of context, so you end up paying for me to acknowledge a check that's obviously irrelevant for a Vue form in a job management app I've been working on for ages."*

**OddDoc** corroborates: *"'This file is clearly not malware...' Literal same reply prefix I got earlier, fucky stuff there."*

**Implication:** Anthropic's per-file-read malware-check system reminder consumes user tokens and produces visible noise. Users are paying for safety telemetry.

## The cleanest operational cheat-sheet

From **aLionChris** (8 upvotes, worth capturing verbatim):

> "Pasting here for others benefit:
>
> - **Effort level:** Anthropic raised the default effort level to the new xhigh in Claude Code for Opus 4.7. They recommend starting at high or xhigh for coding/agentic work.
> - **Token usage will go up:** Opus 4.7 uses an updated tokenizer (same input ≈ 1.0–1.35× more tokens) and thinks more at higher effort levels.
> - **Prompts may behave differently:** It follows instructions more literally than 4.6. If you have prompts/skills tuned for 4.6 (your .claude/skills/*/SKILL.md files, brand voice, SEO briefs, etc.), you may want to re-test them — previously loose interpretations may now be taken at face value.
> - **New /ultrareview slash command:** A dedicated review session that reads through changes and flags bugs/design issues. Pro and Max users get three free ones to try.
> - **Auto mode:** Extended to Max users — Claude makes permission decisions on your behalf for longer autonomous runs."

## Useful model-invocation commands

- **tyschan:** `/model claude-opus-4-7`
- **Jomuz86:** `/model claude-opus-4-7[1m]` for the 1M-context variant (👍 13 upvotes)
- **Final_Sundae4254:** noted UI renders this as "Set model to Opus 4 (1M context)" — may confuse on first use

## What you should actually do

1. **Expect higher usage limits burn** — plan accordingly.
2. **Budget for the tokeniser shift** before committing production workloads.
3. **Re-test existing prompts** against 4.7's literal-interpretation behaviour before switching.
4. **Try `/ultrareview`** on a non-trivial PR with your 3 free Pro/Max invocations.
5. **Switch to xhigh or high** for coding/agentic work (do not leave default).
6. **Know `/model claude-opus-4-7[1m]`** for large-codebase work.
7. **Audit CLAUDE.md files** against the literal-interpretation change (see [prompt discipline]({{ site.baseurl }}/docs/prompt-discipline/)).

## Related Playbook pages

- [Opus 4.7 Reference]({{ site.baseurl }}/docs/opus-4-7/) — full reference + migration checklist
- [Cost & Observability]({{ site.baseurl }}/docs/cost-and-observability/) — measure the usage-limit impact
- [Prompt Discipline]({{ site.baseurl }}/docs/prompt-discipline/) — re-tune CLAUDE.md files for 4.7's literal reading
- [Opus 4.7 — the behavioural release]({{ site.baseurl }}/docs/news/opus-4-7-behavioral-release/) — the Rezvani thesis explaining *why* the usage picture shifted
