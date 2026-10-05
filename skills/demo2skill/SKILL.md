---
disable-model-invocation: true
name: demo2skill
description: >
  Record a demonstration and turn it into a reusable SKILL.md — the Claude equivalent
  of Codex "Record & Replay". Single entry point: "/demo2skill record" starts a
  terminal recording; "/demo2skill" (no args) synthesizes a skill from the newest
  recording; "/demo2skill --browser <export.json>" synthesizes from a Chrome DevTools
  Recorder export. Use when the user says "/demo2skill", "record a demo", "turn this
  demo into a skill", "demo to skill", "I recorded a task, make a skill", or points at
  a demo transcript. Do NOT fire mid-task or to author a skill from scratch with no
  recording (use /skillify for conversation-based extraction instead).
metadata:
  user-invocable: true
  slash-command: /demo2skill
  proactive: false
---

# demo2skill

Synthesize a `SKILL.md` from a recorded demonstration of a task. This is the
"Record & Replay" parity piece: the user *shows* the workflow once (in a recorded
shell, or via Chrome's Recorder), and this skill turns the recording into a skill
draft — rather than `/skillify`, which reads the *conversation*.

**Subscription-safe:** all synthesis runs in this Claude session (or a headless
`claude -p` child with `ANTHROPIC_API_KEY` scrubbed). Never call a paid API.

## Modes (one command to remember: `/demo2skill`)

- **`/demo2skill record [slug]`** — start a recording. The recorder wraps `script`
  and needs a live terminal, which cannot run inside a tool call. So this mode prints
  the **paste-ready command** for the user to run in their own prompt:
  `!~/.claude/scripts/demo-record.sh <slug>`
  (the leading `!` runs it in the user's session). Tell them: run it, do the task,
  type `exit`, then come back and run `/demo2skill` to synthesize. Default slug `demo`.
- **`/demo2skill` (no args)** — synthesize from the newest recording (auto-detect).
- **`/demo2skill --cli <transcript.log>`** — synthesize from a specific transcript.
- **`/demo2skill --browser <export.json>`** — synthesize from a Chrome DevTools Recorder export.

## Inputs

- `--cli <transcript.log>` (default) — a transcript from `~/.claude/scripts/demo-record.sh`.
- `--browser <export.json>` — a Chrome DevTools **Recorder** export (Puppeteer/JSON flow).
- No path → auto-detect the newest file in `./.omc/artifacts/demos/` then `~/.claude/demos/`.

## Workflow — CLI layer (`--cli`)

1. **Clean** the transcript:
   `~/.claude/skills/demo2skill/scripts/clean-transcript.sh <transcript.log>`
   (strips ANSI/control noise + `script` banners).
2. **Extract** from the cleaned text: the ordered command sequence, the working
   directory/branch context, and any obvious decision points (a command that was
   retried, edited, or followed a failure).
3. **Quality gate** (from skillify): proceed only if all true —
   "couldn't be Googled in 5 min", "specific to this user/project/workflow",
   "took real operational effort". If it fails, say so and stop — don't make a slop skill.
4. **Ask ≤2 clarifying questions** via AskUserQuestion: (a) what are the *inputs/variables*
   that change between runs? (b) what is the *success criterion*? Keep it to two.
5. **Synthesize** a `SKILL.md` into `~/.claude/skills/<new-slug>/SKILL.md` using the
   frontmatter shape below. Body = Goal, Inputs, ordered Steps (the extracted commands,
   generalized with the variables from step 4), Verification, Pitfalls.

## Workflow — browser layer (`--browser`)

> Honest constraint: the `chrome-devtools` MCP *drives* the browser; it cannot passively
> log a human's clicks. The capture bridge is Chrome's built-in **Recorder** panel
> (DevTools → Recorder → record → export as JSON). This skill ingests that export.

1. **Parse** the Recorder JSON: each `steps[]` entry has a `type`
   (`navigate` | `click` | `change` | `keyDown` | `waitForElement` | `setViewport`) and
   `selectors`/`url`/`value`. Read `title` + `steps`.
2. **Translate** into a human-readable procedure (one line per meaningful step;
   collapse `setViewport`/`keyDown` noise).
3. **Quality gate** + **≤2 clarifying questions** as above.
4. **Synthesize** `SKILL.md` with: the readable procedure, plus an optional **Playback**
   section expressing the steps as `chrome-devtools` MCP calls (navigate_page → click →
   wait_for) or a Playwright snippet, so the skill can re-run the flow later.

## Output frontmatter (required)

```yaml
---
name: <kebab-slug>
description: >
  <what it does> Triggers: "<phrase>", "<phrase>". Do NOT use for <anti-trigger>.
metadata:
  user-invocable: true
  slash-command: /<slug>
---
```

`description` MUST be < 1024 chars and lead with verbs + triggers (per the user's
`skill-authoring` convention).

## Pre-ship checklist (from skill-authoring)

- [ ] Description leads with what it does + concrete trigger phrases + an anti-trigger.
- [ ] Steps are generalized (variables, not the literal one-off values from the demo).
- [ ] A Verification section exists and is runnable.
- [ ] No secrets/tokens copied verbatim from the transcript — redact to `${ENV_VAR}`.
- [ ] Slug directory is `~/.claude/skills/<slug>/` with `SKILL.md` (exact case).

## Related

- `/skillify` — conversation-based extraction (no recording).
- `~/.claude/scripts/demo-record.sh` — produces the CLI transcript this consumes.
