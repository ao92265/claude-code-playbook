---
name: deep-explore
description: >
  Deep codebase research requiring multi-step exploration across many files. Use when
  the user asks a complex question about how the codebase works that requires tracing
  through 5+ files, following import chains, or mapping architecture. Triggers: "how does
  X work in the codebase", "trace the flow of", "map out the architecture of".

  Do NOT use this skill for: simple file lookups, single grep searches, known file
  locations, implementation tasks, or cross-repo searches (use cross-project-search).
  Don't trigger when OMC's built-in Explore agent would suffice for a 1-3 file lookup.
context: fork
agent: Explore
---

Research the following question thoroughly:

$ARGUMENTS

## Instructions

1. Use Glob to find relevant files by name patterns
2. Use Grep to search for keywords, function names, imports, and references
3. Use Read to examine the most relevant files in detail
4. Trace the flow end-to-end: entry points, middleware, handlers, data transformations, and side effects

## Output Format

Return a structured summary:

### Answer
A concise 2-3 sentence answer to the research question.

### Key Files
List the most important files with their roles:
- `path/to/file.ts` — what it does

### Flow
If applicable, describe the execution flow step-by-step.

### Architecture Notes
Any relevant patterns, design decisions, or gotchas discovered.

### Related
Other files or areas worth investigating if the user wants to go deeper.

## Important
- Be thorough but concise — the summary goes back to the main context
- Include specific file paths and line numbers where relevant
- Don't dump raw file contents — summarize what matters
- If the codebase doesn't contain what's being asked about, say so clearly
