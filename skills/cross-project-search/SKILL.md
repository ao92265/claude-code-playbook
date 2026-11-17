---
name: cross-project-search
description: >
  Search across all repos in the workspace for patterns, implementations, or examples.
  Useful for finding where something is implemented across Example Project, ACT, a personal assistant, legacy system,
  and other projects.

  Do NOT use this skill for: searching within a single project (use Grep or Glob directly
  instead), web searches, or lookups that don't require spanning multiple repositories.
  Don't trigger when you already know which project contains the answer.
context: fork
agent: Explore
title: "cross-project-search"
parent: Skills & Extensibility
---
Search across all projects in /path/to/repos/ for:

$ARGUMENTS

## Instructions

1. Search every repo under the workspace root with Grep (or `grep -rn` from the root) for the pattern, with an optional file glob
   - Example: Grep pattern `ZohoClient`, glob `*.ts`
   - Skip `node_modules/`, `.git/`, `dist/`, `build/`, lock files, and generated directories
   - Group the results by project/repository when you report them
2. For each match, read enough context to understand how it's used

## Output Format

### Search Results

For each project with matches:

#### [Project Name]
- `path/to/file.ts:42` — brief description of how the pattern is used here
- `path/to/other.ts:17` — brief description

### Summary
- Total matches: N across M projects
- Most relevant implementation: point to the best/most complete example
- Patterns observed: note any differences in how projects implement this

## Important
- Search broadly first, then narrow down to the most relevant results
- Include enough context to understand each match without reading the full file
- If searching for an API or integration, note which projects use it and how
- Limit results to the top 20 most relevant matches
- Skip matches in lock files, generated code, and vendor directories
