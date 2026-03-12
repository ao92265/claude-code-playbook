---
name: codex-prepush-review
description: >
  Run Codex to perform a pre-push code review for a given GitHub issue.
  Use when instructed by the user, typically when finished implementing an issue
  and before pushing. Triggers: "review for issue #N", "prepush review", "codex review".

  Do NOT use this skill for: pre-commit review, reviewing code that isn't ready to push,
  non-GitHub repositories, or general code review not tied to a specific GitHub issue number.
  Don't trigger for in-progress work — only use when implementation is complete and push is imminent.
---

# Codex Pre-Push Review

Use this skill when instructed by the user, typically when finished with implementing an issue.

## Purpose

Run OpenAI Codex locally to review changes related to a GitHub issue. Codex will inspect the issue, run git status / git diff as needed, and return a structured review.

## When to use

When instructed by the user, e.g.:
- "review changes for issue #42"
- "prepush review 42"
- "codex review #15"

## How to invoke

Run the script at `~/.claude/skills/codex-prepush-review/run.sh` with the issue number as the sole argument:

```bash
bash ~/.claude/skills/codex-prepush-review/run.sh <issue-number>
```

The script:
- Takes a GitHub issue number as input
- Executes Codex CLI with a structured review prompt
- Writes raw JSON output to a temporary file
- Prints only the filtered review text (agent message output)

## Expected output

1. **Blockers** (must-fix before push)
2. **Important** (should-fix)
3. **Nits** (another-projectnal)
4. **Missing tests** (specific test cases)
5. **Questions for the author** (only if truly needed)

## After review

Do not modify the script behavior. Address blockers before continuing. Present the full review output to the user for decision-making.
