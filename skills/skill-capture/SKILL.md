---
disable-model-invocation: true
name: skill-capture
aliases: [autoskill, learner, skillify]
description: >
  Capture learnings as reusable skills, in four modes: analyze session
  corrections into team/project preferences (corrections), extract a single
  hard-won gotcha into a learned skill (extract), turn a repeatable workflow
  into a full skill draft (workflow), or passively watch a task as it happens
  for skill-worthy patterns (observe). Triggers: "learn from this session",
  "what did you learn", "autoskill", "skillify", "extract a skill", "turn
  this into a skill", "watch for skill opportunities", after completing work
  that involved a user correction.

  Do NOT use for: normal coding tasks, mid-task work, one-off fixes, or any
  task that doesn't involve reviewing/capturing a session as a reusable
  skill. Don't trigger `corrections` mid-task just because a correction
  happened — wait until the work is complete. `observe` is the exception:
  it runs alongside a task, not after it.
metadata:
  user-invocable: true
  slash-command: /skill-capture
  supersedes: [autoskill, learner, skillify]
---

# Skill Capture

Merges four overlapping capture workflows into one skill with four modes.
Pick the mode from how the user (or the situation) invoked this skill; if
ambiguous, ask.

| Trigger phrase                                             | Mode        |
| ------------------------------------------------------------ | ----------- |
| "learn from this session", "autoskill", "what did you learn" | corrections |
| "extract a skill", "learner"                                 | extract     |
| "skillify", "turn this into a skill"                         | workflow    |
| "watch for skill opportunities", start of a multi-step task  | observe     |

## Shared Quality Gate

Before capturing anything in `corrections`, `extract`, or `workflow` mode,
all three must be true:

1. **Non-Googleable** — could someone find this via a 5-minute search? If
   yes, discard (BAD: "use try/catch for error handling"; GOOD: "the aiohttp
   proxy in server.py:42 crashes on ClientDisconnectedError — wrap
   StreamResponse in try/except").
2. **Specific** — is it tied to this codebase, project, or team, with actual
   file paths, error messages, or line numbers? Generic patterns, library
   usage, and boilerplate belong in documentation, not here.
3. **Hard-won** — did it take real debugging, correction, or operational
   effort to surface, and does it apply beyond a single file or one-off task?

If any check fails, discard the candidate and move on.

---

## Mode: corrections (was autoskill)

Analyze the current or recent session for correction signals — places where
the user stated a team/project preference or corrected an approach — and
turn qualifying ones into skill or `CLAUDE.md` updates.

1. **Resolve project context.** Extract the project name from `$CWD` (e.g.
   `/Users/aoreilly/Repos/Wraith` → `wraith`). Check whether
   `.claude/skills/` exists in the project root.
2. **Subcommands** (from `$ARGUMENTS`): `review` = steps 3-5 only, propose
   without applying; `history` = run
   `git log --oneline --grep="autoskill:"` and stop; `apply` = skip to step
   5 using previously proposed learnings; `global` = restrict search/output
   to cross-project preferences; no argument = run steps 3-5 in full.
3. **Search for signals.** Query `mcp__historian__search_conversations` for
   `"no use instead|don't use|we always|we never|our convention|team
   prefers|standard practice"` and separately for `"Actually|Wrong|not like
   that|stop doing"`, filtered to the current project. No signals → report
   "No correction signals detected" and stop.
4. **Filter each signal** against the Shared Quality Gate above, plus:
   **team-relevant?** (benefits the whole project, not one person's taste).
   Drop anything that fails.
5. **Map each surviving signal to a target file:**

   | Content category             | Target file pattern                        |
   | ----------------------------- | -------------------------------------------- |
   | Backend/API/Prisma            | `.claude/skills/{project}-backend.md`        |
   | Frontend/React/components     | `.claude/skills/{project}-frontend.md`       |
   | Testing patterns              | `.claude/skills/{project}-testing.md`        |
   | Database/migrations           | `.claude/skills/{project}-database.md`       |
   | E2E/Playwright                | `.claude/skills/{project}-e2e.md`            |
   | Git/commits/workflow          | `.claude/skills/{project}-git.md`            |
   | API integrations              | `.claude/skills/{project}-integrations.md`   |
   | General project rule          | project root `CLAUDE.md`                     |
   | Cross-project preference      | `~/.claude/global-prefs.md`            |

6. **Propose** each mapped signal as a block: File, Section, Type
   (ADD/MODIFY), Scope (PROJECT/GLOBAL), Content to add (1-3 lines),
   Triggered-by quote, Confidence (HIGH/MEDIUM/LOW), Justification.
7. **Apply.** HIGH confidence proposals apply immediately: create the file
   with minimal frontmatter if missing, insert 1-3 lines into the right
   section without rewriting surrounding content, show the diff. MEDIUM/LOW
   proposals wait for explicit approval. After applying, if the directory is
   a git repo, commit with `autoskill: learned [thing]` + a `Signal:` trailer.

Constraints: 1-3 lines per learning, preserve existing formatting, never add
hooks automatically.

---

## Mode: extract (was learner)

Extract one hard-won insight from the current conversation as a standalone
learned-skill file — a principle or heuristic, not a code snippet to
copy-paste. BAD: "when you see ConnectionResetError, add this try/except."
GOOD: "in async network code, wrap each I/O operation separately — failure
between operations is the common case, not the exception."

1. **Gather:** Problem statement (exact error/symptom, file:line), Solution
   (exact fix, not general advice), Triggers (keyword fragments that would
   recur — error text, file names, symptoms), Scope (almost always
   project-level).
2. **Validate** against the Shared Quality Gate. Reject vague solutions with
   no code/paths, or triggers generic enough to match everything.
3. **Classify:** Expertise (domain knowledge/pattern/gotcha, updatable
   independently) vs Workflow (operational step sequence, stable).
4. **Save location:**
   - User-level (rare, only truly portable insights):
     `${CLAUDE_CONFIG_DIR:-~/.claude}/skills/omc-learned/<skill-name>.md`
   - Project-level (default, commit with the repo to share with the team):
     `.omc/skills/<skill-name>.md`
   - Note: in linked worktrees, uncommitted skills are worktree-local and
     disappear if that worktree is deleted.
5. **Write the file** with required frontmatter (never emit plain markdown
   without it):

   ```yaml
   ---
   name: <skill-name>
   description: <one-line description>
   triggers:
     - <trigger-1>
     - <trigger-2>
   ---
   ```

   Body sections: `## The Insight` (the underlying principle, not the code),
   `## Why This Matters` (what breaks if you don't know this), `##
   Recognition Pattern` (how you know it applies), `## The Approach` (the
   decision heuristic), `## Example` (optional, illustrative only).

A skill is reusable if it applies to *new* situations, not just this exact
one — that's the bar for saving it.

---

## Mode: workflow (was skillify)

Capture a successful repeatable multi-step workflow from the session as a
concrete skill draft, before it has to be rediscovered later.

1. Identify the repeatable task the session accomplished.
2. Extract: inputs, ordered steps, success criteria, constraints/pitfalls,
   verification evidence, and the best target location.
3. Decide the target: a repo built-in skill, a user/project learned skill,
   or documentation only (if it's not really repeatable, say so and stop).
4. If drafting a learned skill file, use the same frontmatter requirement
   and save paths as `extract` mode above
   (`${CLAUDE_CONFIG_DIR:-~/.claude}/skills/omc-learned/<skill-name>.md` or
   `.omc/skills/<skill-name>.md`). Never write frontmatter-less markdown.
5. Draft the full file: clear triggers, ordered steps, explicit success
   criteria (prefer these over vague prose), and pitfalls.
6. Flag anything still too fuzzy or branchy to encode safely — note the open
   question rather than guessing at a resolution.

Output: proposed skill name, target location, the draft (or complete file),
quality-gate notes, open questions.

---

## Mode: observe (was task-observer, core only)

A light, passive mode for the *start* of a multi-step task, not a
post-hoc review. While using tools and producing deliverables, keep a
running eye out for: user corrections that imply a durable rule, a
multi-step sequence repeated more than once in the session, a tool
limitation that reshapes the right approach, or a technique that worked
unexpectedly well. Don't interrupt the task to act on these — jot a
one-line observation (what happened, why it's skill-worthy) and keep
working.

At session end, or when explicitly asked ("what did you observe",
"skill observations"), summarize what was logged and recommend which mode
above should process each one: a correction signal → `corrections`, a
single hard-won gotcha → `extract`, a repeated procedure → `workflow`. Don't
run those modes automatically from inside `observe` — surface the
recommendation and let the user (or the next invocation) decide.

This mode intentionally does not port task-observer's project-log
infrastructure, GitHub-issue feedback routing, or weekly-review cadence —
those are out of scope for a lightweight in-session watch.
