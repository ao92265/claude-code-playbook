---
title: Meta Spark Muse — skip
parent: Models & Vendors
grand_parent: News & Research
nav_order: 9
---
# Meta just dropped a new coding model (Spark Muse)

**Source:** r/ClaudeCode, [u/Complete-Sea6655 — "Meta just dropped a new coding model"](https://www.reddit.com/r/ClaudeCode/comments/1sg51ut/meta_just_dropped_a_new_coding_model/) (2026-04-08)

## Key takeaways

- **Skip Meta Spark Muse.** Agentic section is weak vs Opus 4.6; multimodal is the best part.
- Chart-crime post (Meta's benchmarks coloured blue despite being worse).
- Community trust in Meta as an AI vendor is very low.
- The **valuable takeaway** is the *surrounding discussion* — the loop-breaker heuristic, Google Vertex training-data concerns, Dwarkesh on Anthropic not benchmark-maxxing.

## OP's take on the model

- Multimodal looks the best part of Spark Muse
- **Agentic section is pretty bad vs Opus 4.6**
- Chart-crime observation: *"all the numbers are in blue even though they are worse than the comparisons, quite misleading"*

Source chart: `ijustvibecodedthis.com`

## Community sentiment — overwhelmingly skeptical

### On Spark Muse specifically

- **k_means_clusterfuck:** *"What in the chart crime"*
- **dooddyman:** *"Benchmarks at this point is like competing to being a better power lifter when the actual league is UFC"*
- **randomrealname:** *"They are now 2, nearly 3 runs behind even Google. Stagnation is real."*
- **InstaMatic80:** *"Wow meta still alive and kicking? Where are the weights?"*

### On Meta as a vendor

- **Twig (131 upvotes):** *"Not a fucking chance I use meta for anything."*
- **csueiras (88 upvotes):** *"Meta is cancer"*
- **Acrobatic_Response58 (64 upvotes):** *"rememeber cambridge analytica? feel old yet?"*

### The steel-manned counter

- **Impossible_Raise2416:** *"well they did give us pytorch, react and kick started the open weights era (although not willing, but by a researcher leaking the model)"*

### WouldRuin's prediction

> "People will (rightly) dunk on Meta, but ignore that a lot of people working at other AI companies will have cut their teeth at Meta, and probably worked on products that have been actively harmful to the fabric of society. I think in 10 years time we'll look back and be like, the same people that created toxic, addictive social media products have created... toxic, addictive AI products. How could this have happened? Personally I think Meta shouldn't be anywhere near AI products, but here we are."

## The valuable discussion — what the thread is actually useful for

The highest-signal content is the meta-discussion in the top replies. Worth reading the thread for these even if Spark Muse itself is uninteresting.

### Benchmarks vs real-world coding (NoCat2443 — 179 upvotes)

> "Benchmarks — here opus is worse than rest but still beats them in actual coding thanks to the right tooling and probably more actual quality rather then test readiness"

### Anthropic vs the field (Complete-Sea6655 — 72 upvotes)

> "Dwarkesh [Patel] was saying that it seems like anthropic are the only ones not benchmarkmaxxing"

### Codex vs Opus — they're complementary (Crazy-Problem-2041 — 38 upvotes)

> "Codex and opus are much closer than most people admit. I find codex much better for really difficult problems and systems debugging. But Anthropic's internal benchmarks and post training are much more aligned to actual day to day coding. E.g. a lot of just making sure that any table they output is formatted properly etc, which is really nice for day to day coding so I use it way more"

### The loop-breaker heuristic (MyLifeStyle89)

> "Agree. When Opus got a loop on solving a problem, I just give it to Codex and it solves it flawlessly, especially about auth or db. Opus got a tendency of overthinking while Codex just directly pinpoint the problem."

This is the single most useful practical insight in the entire thread. When Opus overthinks, hand the problem to Codex. Validates OMC's CCG tri-model orchestration + Liu's adversarial-review flow.

### Cross-model feedback (wakkowarner321)

> "I find I can't generalize which one is better. I find that when I work with one for awhile, I like it. Seems to be doing smart things. Then I run into a problem, a roadblock, that it can't seem to get past. I then give the problem to the other. If its really hard it may take a few tries, but it finally unjams everything. Or it just sees the problem in a different way and fixes it immediately. I really like pitting them against each other, offering feedback back and forth."

### Google Vertex training-opt-out concern (immutato)

> "Codex was around the same when I last tried in (4+ months ago?), with an edge over Sonnet IMO. Google though... maybe it's just tooling or w/e, but it hasn't produced quality code for me, and the fact that they use our data for training with no way to opt out, even with a max personal sub is the dealbreaker for me (fine if you can do the google workspace thingamajig I guess)."

### Even with the same tooling (Difficult-Visual-672)

> "not only tooling, you can use them all on opencode with the same tooling and yet opus tends to be better overall"

## Net verdict

- **Skip Meta Spark Muse.** Agentic performance is weak vs Opus; vendor trust is too low for enterprise consideration.
- **Read the thread anyway** for the loop-breaker heuristic, the Dwarkesh "Anthropic isn't benchmark-maxxing" line, and the Google Vertex data-opt-out concern — all three are reusable signals worth having in hand.

## Related Playbook pages

- [Multi-Model Orchestration]({{ site.baseurl }}/docs/multi-model-orchestration/) — the loop-breaker heuristic operationalised
- [Regulated AI]({{ site.baseurl }}/docs/regulated-ai/) — Google Vertex training-opt-out is an enterprise blocker worth knowing about
- [Local Models]({{ site.baseurl }}/docs/local-models/) — Gemma 4 is Google's credible open-weights option regardless of Meta
