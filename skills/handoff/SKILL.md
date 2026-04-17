---
name: handoff
description: >
  Write a structured session handoff summary so the next session picks up cleanly.
  Captures what was done, what's left, decisions made, and gotchas.
  Triggers: "handoff", "session summary", "wrap up", "save progress", "end of session".

  Do NOT use this skill for: mid-session notes, creating plans for new work, or
  generating documentation for end users.
metadata:
  user-invocable: true
  slash-command: /handoff
  proactive: false
title: "Session Handoff"
parent: Skills & Extensibility
---
# Session Handoff

Create a structured handoff document so the next Claude Code session (or another developer) can pick up exactly where you left off.

## Steps

1. **Summarize what was accomplished:**
   - List files created, modified, or deleted
   - Describe each change in one sentence
   - Note any tests added or modified

2. **Document what's left to do:**
   - Remaining tasks from the original request
   - Known issues discovered during implementation
   - Tests that still need to be written
   - Edge cases identified but not yet handled

3. **Record decisions made:**
   - Architecture or design choices and why they were made
   - Alternatives that were considered and rejected (with reasons)
   - Trade-offs accepted (e.g., "chose simplicity over performance because...")

4. **Flag gotchas and warnings:**
   - Anything that's fragile or could break easily
   - Dependencies on external systems or specific configurations
   - Environment-specific requirements (env vars, services, ports)
   - Known limitations of the current implementation

5. **Capture the current state:**
   - Branch name and last commit hash
   - Test results (passing/failing counts)
   - Build status (clean or known errors)
   - Any running processes or servers that need to be stopped/started

6. **Write to SESSION_NOTES.md:**
   - Save in the project root as `SESSION_NOTES.md`
   - Replace contents if file already exists (don't append)
   - Keep under 50 lines — concise is better than comprehensive
   - Include date and time at the top

## Output Format

```markdown
# Session Handoff — [DATE]

## Completed
- [file]: [what changed]

## Remaining
- [ ] [task]

## Decisions
- [decision]: [rationale]

## Gotchas
- [warning]

## State
- Branch: [name] @ [hash]
- Tests: [X passing, Y failing]
- Build: [clean/errors]
```

## Important

- **Replace, don't append.** SESSION_NOTES.md should reflect the latest session only.
- **Be specific.** "Fixed the auth bug" is useless. "Changed token expiry from 1h to 24h in src/auth/config.ts" is useful.
- **Include the why.** Future sessions need context, not just facts.
- **Keep it short.** If the summary exceeds 50 lines, you're including too much detail.
