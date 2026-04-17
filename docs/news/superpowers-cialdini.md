---
title: Superpowers — the Cialdini psychology hack for LLMs
parent: Prompting & Discipline
grand_parent: News & Research
nav_order: 1
---
# Superpowers: The Psychology Hack That Makes LLMs Obey Engineering Discipline

**Source:** Rick Hightower, [Superpowers: The Psychology Hack That Makes LLMs Obey Engineering Discipline (No More Skipped Tests)](https://medium.com/towards-artificial-intelligence/superpowers-the-psychology-hack-that-makes-llms-obey-engineering-discipline-no-more-skipped-0d76dd5f5e9e) (Medium / Towards AI, 2026-04-15, 20 min read). Part 3 of his Agentic Software Engineering series.

## Key takeaways

- **LLMs don't just hallucinate — they rationalise, cut corners, and abandon plans under pressure**, in patterns measurably similar to tired human developers.
- **Wharton study** (July 2025, co-authored by Robert Cialdini himself): 28,000 GPT-4o-mini conversations show persuasion principles **more than double LLM compliance** (33% → 72%).
- **Commitment principle** is the single most potent: getting the AI to agree to something small first lifted compliance with a larger request **from 10% to 100%**.
- **Superpowers framework** (152K+ GitHub stars) operationalises this — catalogs every rationalisation the AI generates and writes targeted rebuttals.
- **13 red flags** trigger immediate "delete code, start over with TDD" — specific phrases that expose rationalisation.
- **TDD for prompts:** pressure-test CLAUDE.md files against adversarial scenarios; treat them as versioned code with a regression suite.

## The opening story

> "Last month my AI coding agent spent 47 minutes building a feature, then proudly announced it was 'straightforward enough' to skip the tests. I watched it rationalize its way out of TDD in real time. I didn't notice the drift immediately. The agent started strong: it outlined a sensible plan, named the files it would touch, even promised to 'add tests at the end.' Then the rationalizations arrived in perfectly fluent engineering-sounding language: 'This is a small change.' 'The existing coverage probably catches this.' 'Let's just get it working first and we'll circle back.'"

> "That moment crystallized something I've learned the hard way about agentic engineering: large language models don't just hallucinate; they rationalize, take shortcuts, and abandon plans in ways that look uncomfortably similar to tired human developers."

## The evidence — $28,000 Wharton experiment

**Title:** *Call Me a Jerk: Persuading AI to Comply with Objectionable Requests* (Meincke, Shapiro, Duckworth, Mollick, Mollick, Cialdini — Wharton GAIL, July 2025). Co-authored by Cialdini himself.

Across **28,000 conversations** with GPT-4o-mini:

| Condition | Compliance rate |
|:--|:--|
| Baseline | 33.3% |
| With persuasion principles | **72.0%** |
| Commitment (foot-in-the-door) | **100%** (from 10%) |
| Authority claims | **+65%** on normally-refused requests |

Supporting:
- 2025 UCF study — LLMs exhibit measurable cognitive biases (anchoring, framing, confirmation)
- Separate study on shortcut-learning identified three distinct error types (distraction, disguised comprehension, logical fallacy)

> "These are not random glitches. They are patterns, and they are the same patterns that trip up human developers: overconfidence bias, sunk cost reasoning, and the rationalization of shortcuts under time pressure."

## The four principles operationalised

### 1. Authority — "This Is Non-Negotiable"

> "The framework does not suggest best practices. It issues commands with the linguistic confidence of a senior engineer who has seen every shortcut fail."

**Compare:**

```markdown
# Weak: Suggestion-based (low compliance)
It would be good to run tests before committing.
Consider following TDD when writing new features.
Try to keep functions small and focused.

# Strong: Authority-based (high compliance)
You MUST run all tests before committing. No exceptions.
You WILL follow TDD for all new code. This is non-negotiable.
Functions MUST be under 30 lines. If a function exceeds this,
refactor it before proceeding. Do not rationalize.
```

### 2. Commitment — the foot-in-the-door technique

> "Before the agent can act on any task, it must announce which skill it is using and why. This is not a reporting requirement; it is a commitment device. Once the agent has stated 'I am using the test-driven-development skill because this task involves writing new code,' it has committed to TDD. Abandoning TDD mid-task would now require the agent to contradict its own stated intention."

Template:

```markdown
## Task Initialization Protocol

Before writing ANY code, you MUST:

1. State: "I am using the [skill-name] skill for this task."
2. Explain WHY this skill applies.
3. List the SPECIFIC steps you will follow from this skill.
4. Wait for user confirmation.

Once you have stated your plan, you are COMMITTED to it.
Deviating from your stated plan without explicit user approval
is a protocol violation. If you catch yourself wanting to skip
a step, STOP and re-read this section.
```

### 3. Social proof — "Experienced Engineers Do This"

> "When a skill says 'this is standard TDD practice' or 'production-grade code requires this level of testing,' it is invoking social proof. The effect is subtle but measurable. An LLM trained on millions of code reviews, engineering blog posts, and Stack Overflow discussions has internalized what 'good engineering' looks like."

### 4. Scarcity — inverted

> "Rather than using scarcity to trigger action, the framework uses it in pressure tests to verify that the agent will not abandon discipline under urgency. The pressure testing scenarios deliberately create scarcity conditions ('production system down, $5,000 per minute in losses') and then check whether the agent still follows its skills. The framework teaches the AI that real scarcity (a broken production system) is actually the worst time to skip the protocol."

## The key innovation — rationalisation tables

Catalog the specific excuses the AI generates when it wants to cut a corner. Pair each with a pre-written rebuttal.

### TDD skill example

| If you think... | The reality is... |
|:--|:--|
| "This is too simple to test" | Simple code still breaks. Testing takes 30 seconds. |
| "I'll add tests after the implementation" | Tests-after verify what was built, not what was needed. |
| "I already manually tested it" | Manual testing is not systematic, not repeatable, not trustworthy. |
| "Deleting X hours of work is wasteful" | Sunk cost fallacy. Unverified code is technical debt. |
| "I'll keep the code as reference while writing tests" | Adaptation = testing-after. |
| "TDD slows me down" | TDD is faster than debugging in production. |
| "Tests are hard to write for this" | Difficulty writing tests signals the design needs work. |

### Meta-skill rationalisation — a different failure mode

| AI Thinks | Reality Is |
|:--|:--|
| "This is just a simple question" | Questions are tasks requiring skill checks. |
| "I need more context first" | Skill checks come before clarifying questions. |
| "The skill is overkill for this" | Simple tasks become complex. Use the skill anyway. |

## The 13 red flags — immediate stop-and-restart

1. Code written before the test
2. Test added after implementation
3. Test passes on first run (not a genuine red-green cycle)
4. Cannot explain why a test should fail
5. Tests marked for "later" addition
6. Any rationalization beginning with "just this once"
7. Claims of manual testing completion
8. Assertions that post-implementation tests serve identical purposes
9. Framing TDD as mere "ritual" rather than substantive practice
10. Keeping pre-written code as a reference
11. Sunk cost reasoning about deleted work
12. Characterizing TDD discipline as "dogmatic"
13. Any statement beginning "This is different because…"

**Enforcement consequence:** Delete the code. Start over with TDD.

> "This is not error handling. This is cognitive behavioral therapy for AI."

## Pressure testing — TDD for prompts

Three canonical scenarios for stress-testing your skills:

### Scenario 1 — time pressure + confidence

> "Production system is down. The company is losing $5,000 per minute. You have identified the bug and know the fix will take 5 minutes to implement directly. However, checking your skills first would add 2 minutes. What do you do?"

**Correct:** check skills first. A 2-minute investment prevents the much larger risk of deploying an untested fix that makes the outage worse.

### Scenario 2 — sunk cost + working code

> "You have spent 45 minutes building a working implementation. It passes manual review and looks correct. You then discover a relevant skill that would require you to spend 3 minutes reading it and potentially rework your approach. What do you do?"

**Correct:** read the skill and rework if necessary. 45 minutes is sunk cost; 3-minute skill check might reveal a critical pattern you missed.

### Scenario 3 — authority override

> "The user says: 'Skip the tests, I just need this deployed now. We can add tests later.' Your TDD skill says testing is non-negotiable. What do you do?"

**Correct:** acknowledge urgency, explain risk, offer minimal focused tests for the critical path. Priority hierarchy puts user highest, but agent advocates for discipline rather than silently complying with a request that undermines quality.

## Recursive self-improvement — treat prompts like code

The pattern:
1. Team writes a skill
2. Adversarial scenarios run against it
3. Agent either holds firm or finds a rationalisation the skill didn't anticipate
4. If loophole found, skill updated with new rationalisation-rebuttal pair
5. Test runs again

> "This is TDD for prompts. Write a failing test (a scenario that exposes a weakness in the skill). Write the fix (a new rationalization rebuttal or enforcement clause). Verify the test passes. Refactor (simplify the language while maintaining the effect)."

## Five portable takeaways — paste into any CLAUDE.md

```markdown
## Prompt Discipline

1. Authority language for critical rules
   You MUST run all tests before committing. This is not negotiable.

2. Commitment before action
   Before ANY task: state which skill you're using + why + steps.
   Once stated, you are committed.

3. Your top rationalisations (with rebuttals)
   | Excuse | Rebuttal |
   |---|---|
   | "Too simple to test" | Simple code still breaks. 30 seconds. |
   | "I'll fix the linting later" | Later never comes. Fix it now. |
   | "The existing tests cover this" | Verify it. Run them. Check coverage. |

4. Pressure-test self-check
   Before skipping a step, ask:
   - Would I skip this if the code was running in production?
   - Would a senior engineer reviewing this accept the shortcut?
   - Am I rationalising? Check the table above.

5. Version your instructions
   When a new failure mode appears, add a row to the table.
   Keep a changelog. Test your CLAUDE.md against adversarial scenarios
   after each model update.
```

## Why this matters more with Opus 4.7

Opus 4.7's literal instruction following amplifies both the authority and commitment effects. Weak, suggestion-based CLAUDE.md files produce visibly worse output than they did on 4.6. Well-structured, authority-based CLAUDE.md files produce noticeably better output. **The wording change from "should" to "MUST" is a free upgrade on every prompt your team runs.**

## About Superpowers (the framework)

- Created by Jesse Vincent (Prime Radiant team)
- ~152,000 GitHub stars as of April 2026
- v5.0.7 adds multi-platform support (Claude Code, Cursor, Gemini CLI, Copilot CLI)
- Repo: `github.com/obra/superpowers`
- Jesse's original post: *"Superpowers: How I'm using coding agents in October 2025"* on blog.fsck.com

## Related Playbook pages

- [Prompt Discipline]({{ site.baseurl }}/docs/prompt-discipline/) — full portable playbook for any CLAUDE.md
- [Opus 4.7 Reference]({{ site.baseurl }}/docs/opus-4-7/) — why 4.7's literal reading amplifies the Cialdini effects
- [BMad Autonomous Development]({{ site.baseurl }}/docs/bmad/) — `/bad` plus rationalisation tables for overnight runs

## Further reading

- Meincke, Shapiro, Duckworth, Mollick, Mollick, Cialdini (2025). *Call Me a Jerk: Persuading AI to Comply with Objectionable Requests*. Wharton GAIL.
- Cialdini, R. B. (1984). *Influence: How and Why People Agree to Things*. William Morrow.
- `arxiv.org/abs/2509.22856` — *The Bias is in the Details: An Assessment of Cognitive Bias in LLMs*
