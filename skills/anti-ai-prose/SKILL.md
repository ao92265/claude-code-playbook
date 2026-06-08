---
name: anti-ai-prose
description: De-AI prose written by an LLM. Strips AI tells and rewrites in real-human voice modelled on Reddit/HN/dev-Twitter writing. Triggers "/anti-ai-prose", "less AI", "no one writes like that", "make it human", "de-slop", "sounds like ChatGPT", and rewrite requests for Viva/Slack/Teams/email/blog/reddit/HN drafts.
---

# Anti-AI Prose

Default LLM writing has a smell. This skill kills it.

## The problem with rule-based de-AI-ing

A clean, balanced, well-structured paragraph is itself a tell. Real people write asymmetrically. They run sentences together, drop subjects, use "it" with no antecedent, swear when annoyed, abandon a thought mid-line.

Rules to delete AI tells aren't enough. You also have to write like a person who's tired and slightly pissed off.

## Banned patterns (AI fingerprints)

### Structural
- **Em-dash mid-sentence flourishes.** ("Claude is great — but it's a black box.") → split into two sentences.
- **Parallel triplets / quads.** ("Sub-agents fork off, hooks fire, MCP servers chew tokens.") → pick the strongest one. Cut the rest.
- **Numbered/comma-separated lists inside a sentence** when prose would do.
- **Signposting.** "First...", "Second...", "Finally...", "In summary..." Humans don't number paragraphs.
- **"It's not just X, it's Y"** / **"Whether you're A or B, this is C"** constructions.
- **Bold every 3rd noun.**
- **Section headers for a single paragraph.**

### Openers
"Hey all", "Hey team", "So here's the thing", "I wanted to share", "Let me tell you", "I've been thinking about", "Picture this", rhetorical questions.

### Vocabulary
- **Hype:** amazing, powerful, transformative, game-changing, revolutionize, unlock, supercharge, seamless, robust, leverage, utilize, dive deep, comprehensive, holistic, paradigm, journey.
- **Hedge:** you should, try to, generally, usually, typically, where appropriate, if possible, it's worth noting.
- **Filler:** at the end of the day, in today's fast-paced world, in the rapidly evolving landscape.
- **OSS-template:** "Issues and PRs welcome", "Contributions appreciated", "Star if you find it useful", "Star history".

### Closers
"I hope this helps", "Let me know if you have any questions", "Looking forward to your thoughts", "Cheers!", "Stay tuned", "Until next time".

## Register-neutral tells (detection pass)

The patterns above target casual voice. These fire in **any** register — casual *and*
formal (Viva, blog, professional). Run this pass before the casual rewrite; on formal
drafts where lowercase/profanity don't apply, this pass is the whole job. Each is **detect → fix**.

1. **Significance inflation.** "stands as / serves as a testament", "a pivotal moment", "plays a vital/crucial role", "marked a turning point", "reflects a broader shift". → State the plain fact. Cut the importance claim.
2. **"-ing" analysis tails.** Trailing participial clauses that editorialize: "..., highlighting its impact", "..., underscoring the need", "..., reflecting a shift", "..., ensuring success". → Delete the tail, or make it a separate concrete sentence.
3. **Copulative avoidance.** "serves as", "stands as", "boasts", "features", "acts as" where "is/has" would do. → Use "is" / "has".
4. **"Despite its X, faces challenges..." conclusion.** Formulaic challenge-then-future-outlook wrap-up. → Cut it. End on a fact.
5. **Vague attributions.** "Industry reports", "Observers have noted", "Experts argue", "Critics say", "It is widely regarded". → Name the source or delete the claim.
6. **Elegant variation.** Swapping synonyms for the same noun to dodge repetition ("the tool" → "the solution" → "the platform"). → Repeat the plain word.
7. **Negative parallelism (extends the "It's not just X, it's Y" rule above).** Also: "not a mirror but a portal", "not A, not B, just C". → One positive statement.
8. **Travel-brochure words.** "nestled", "in the heart of", "vibrant", "rich tapestry", "boasts a thriving", "breathtaking". → Plain description.
9. **Rule-of-three padding (see "Parallel triplets" above).** Three-adjective or three-clause runs faking comprehensiveness. → Keep the strongest, cut the rest.
10. **Smart quotes & curly apostrophes.** `“ ” ‘ ’` from AI / word-processor paste. → Straight `"` and `'`.
11. **Title Case Headings.** Capitalizing Every Word In A Heading. → Sentence case.
12. **AI vocabulary cluster (extends the Hype list above).** "delve", "intricate", "interplay", "landscape", "meticulous", "underscore", "tapestry", "testament", "garner", "bolster", "align with", "showcasing", "fostering". → Cut or use a plain word.

Quick scan:

| Tell | Smells like | Fix |
|---|---|---|
| Significance inflation | "stands as a testament to innovation" | state the fact, drop the claim |
| "-ing" tail | "..., highlighting its impact" | delete or split out |
| Copulative avoidance | "serves as the hub" | "is the hub" |
| Despite/challenges wrap-up | "Despite its success, it faces challenges" | cut, end on a fact |
| Vague attribution | "Experts argue" | name the source or cut |
| Elegant variation | tool → solution → platform | repeat "tool" |
| Negative parallelism | "not a mirror but a portal" | one positive statement |
| Travel-brochure | "nestled in the heart of" | plain description |
| Rule-of-three | "fast, reliable, scalable" | pick one |
| Smart quotes | `“ ” ‘ ’` | `" '` |
| Title Case Heading | "Key Benefits And Features" | "Key benefits and features" |
| AI vocab | "delve into the intricate landscape" | cut / plain words |

## Voice model: r/programming + HN + dev Twitter

Read this. This is what real people write like:

> "tried this for a week, broke twice, both times my fault. would use again."
>
> "ok so this is wild. I had 47 chrome tabs open across 3 windows and the memory usage was... 280mb. wtf."
>
> "spent four hours debugging a typo. AMA"
>
> "honestly the docs are great. the dx is terrible. those are different things."
>
> "shipped a thing. nobody asked for it. here's the link anyway"
>
> "tldr: pay $5/mo or self-host, both fine. no nonsense."

What's going on:

1. **Lowercase to start.** Headers, sentences, sometimes proper nouns.
2. **Asymmetric.** Some sentences run on. Some are two words.
3. **Self-deprecating.** Own the mistake before someone else points it out.
4. **No transitions.** Paragraph breaks do the work.
5. **Specific over general.** "47 chrome tabs", not "a lot of tabs".
6. **Swears or mild profanity** where it matches the mood. ("wtf", "fucked", "broke").
7. **Internet shorthand** in moderation: "tbh", "imo", "fwiw", "ngl", "tldr", "ymmv", "iirc".
8. **Trail off.** End with "anyway", "...so yeah", "idk". Not a wrap-up sentence.
9. **Numbers, not adjectives.** "$443/mo", not "significant savings".
10. **One voice the whole way through.** Don't pivot to corporate at the call-to-action.

## What actually makes writing read as human (lesson learned the hard way)

Throat-clearing filler ("Right.", "Like,", "So here's the thing", "Anyway,") is **the LLM's idea of casual**. Real technical posts on HN, lobsters, dev blogs do not start with mood words. They start with a fact or a problem. Adding filler is the same bug as adding hype: trying-too-hard text in the opposite direction.

The real signal of human-written technical posts:

1. **Open with a fact or a question, not mood.** "I'm on Claude Max so I don't pay per token, but I wanted to know what my usage *would* cost." That's a real opener. "Right. So the bill came in" is a fake-casual cosplay.
2. **Don't perform casualness.** Cut "honestly", "tbh", "like,", "anyway,", "to be fair", "the thing is". They look human in dialogue but feel forced in a written post.
3. **State the constraint upfront.** "$200/mo Max sub" or "free tier" or "company-paid API". Readers want to know your situation before they trust the numbers.
4. **Specific, mundane detail beats curated detail.** Real posts mention things that don't serve the narrative ("the dashboard widget is buggy on Firefox", "this only matters if you're on macOS"). LLM omits those.
5. **One opinion the AI would never volunteer.** Something self-deprecating about the *thing you built*, not the *self*. "The recommender's confidence scores are basically vibes right now" > "I'm not a great writer".
6. **Skip transitions.** Two paragraphs in a row with no bridging sentence. AI can't help itself.
7. **End flat.** "Code's here. Issues welcome." Not a half-joke. Not a CTA. Not a sign-off flourish.
8. **Consistent voice the whole way through.** Don't slip from dry/technical to chummy/casual.
9. **Numbers in the body, not the headline.** Headline states the thing; numbers prove it down-page.
10. **Don't open the same post twice.** AI tends to recap its own opening in the second paragraph. Cut that.

## Things to fact-check before rewriting

LLMs hallucinate the financial framing. Before drafting:
- Is the dollar number a real bill, an estimate, an opportunity cost, or an API-equivalent?
- Is the author on a flat subscription, pay-per-token, free tier, or company-paid?
- Are "savings" actual cash back or hypothetical?
- Are session counts from a tool or counted by hand?

Verify with the user. Mis-stating any of this destroys credibility.

## Rewrite workflow

1. **Read the draft aloud.** If you wouldn't say a line to a colleague over coffee, rewrite it.
2. **Cut 30%.** First-pass AI prose is bloated. Lose connective tissue.
3. **Find the parallel structures.** Kill all but one element.
4. **Lowercase the start of at least one sentence.** Optionally headers too if channel allows.
5. **Insert one self-deprecating line.** Wasted time, broken thing, own stupidity.
6. **One specific, concrete number** in the opening third.
7. **Endings:** short, flat, sometimes funny. Never inspirational. Never a wrap-up.
8. **Final pass:** count em-dashes. >2 in a short piece = still AI.

## Per-channel voice guide

| Channel | Capitalisation | Profanity | Length | Closer |
|---|---|---|---|---|
| Reddit | lowercase OK | yes | short | "anyway", "idk", "ymmv" |
| HN | mostly proper | rare | medium | technical point, no closer |
| dev Twitter | mixed | yes | tweet-length | nothing or "ship it" |
| Slack/Teams (internal) | proper | mild | short | first name |
| Viva/intranet | proper | none | medium | first name |
| Blog post | proper | sparingly | medium-long | flat observation |

## Calibration

**AI version:**
> Hey everyone! I'm thrilled to share an exciting new tool I've been working on. Claude Observatory is a powerful, comprehensive toolkit that empowers developers to gain deep insights into their Claude Code usage. Whether you're optimizing costs or debugging workflows, this elegant solution transforms how you think about AI agent observability!

**Reddit version:**
> spent $8k on claude last month. no idea where it went. wrote a thing. github link below.
>
> it watches your hooks/tools live and reads the jsonl files to tell you where you're burning tokens. found 10 sessions on opus that should've been sonnet = $443/mo i was just lighting on fire.
>
> v0.1, rough as hell. apache 2.0.

**HN version:**
> The Claude Code dashboard tells you the total but not the breakdown. I wanted a per-session/per-skill view, so I wrote one. It's a local Python tool that reads the JSONL files Claude already writes and surfaces tools that go unused, sessions where Opus was overkill, and CLAUDE.md rules that get ignored.
>
> On my own 30 days: $443/mo of opus-on-trivial work I'd missed.
>
> https://github.com/ao92265/claude-observatory

**Viva/internal version:**
> Looked at the Claude bill last week and couldn't tell which sessions cost what. Wrote a small Python tool to find out. Surfaces things like Opus runs that should have been Sonnet, MCP servers nobody uses, CLAUDE.md rules the model ignores.
>
> Tried it on my own usage: $443/month I didn't realise I was burning. Posting in case it's useful to anyone here.
>
> Apache 2.0. Demo on Teams whenever. — Alex

## When NOT to use

- Inside code blocks, commit messages, error quotes.
- Marketing copy where hype is explicitly requested.
- Compliance / legal / formal documentation.

## Output contract

Return ONLY the rewritten document. No "here's what I changed" preamble. No diff. No "let me know what you think".
