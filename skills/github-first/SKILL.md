---
name: github-first
description: Before building a new tool, skill, script, app or integration from scratch, search GitHub for well-starred existing projects that already solve it, then decide adopt, adapt or build. Use when the user says "build me", "make a tool", "make a skill", "write a script that", "set up a", "can we make", "/github-first", "has someone built this", "find prior art", "don't reinvent the wheel", or when brainstorming or prdforge starts on something non-trivial and new. Do NOT use for edits to existing code, bug fixes, one-line scripts, or when the user already named the repo to use.
---

# GitHub first

Search before building. Someone has usually built 80 percent of it, and a
repo with a thousand stars has had its edge cases found by other people.

## Steps

1. **Name the job in 3 to 6 search terms.** The job, not the tech ("pdf invoice
   parse", not "python library").
2. **Search.** Run two or three variations:
   ```
   gh search repos "<terms>" --sort stars --limit 10 \
     --json fullName,description,stargazersCount,pushedAt,license
   ```
   Also check local first: `~/.claude/skills`, `~/.claude/plugins`,
   `~/Repos`, and the memory index. A thing he already has beats any repo.
3. **Filter.** Keep repos with 1,000+ stars (or 200+ for a niche job), a push in
   the last 6 months, and a licence that allows reuse (MIT, Apache, BSD).
   Drop anything with no licence.
4. **Read the top 3.** README plus a look at the main source files
   (`gh api repos/OWNER/REPO/readme`). Security skim: install scripts that
   fetch remote code, `curl | bash`, obfuscation, credential handling.
5. **Decide, one of three:**
   - **Adopt**: install it as is. Only if it fits with little glue.
   - **Adapt**: copy the approach or the relevant files, keeping the licence
     notice, and build the rest.
   - **Build**: nothing fits. Say why in one line per repo checked.
6. **Report**: a table of repos checked (name, stars, last push, verdict) and
   the decision. Put it in the plan or PRD if one is being written.

## Rules

- This is a 5 to 10 minute step, not a research project. Cap at 3 searches
  and 3 READMEs unless the user asks for more.
- Never install anything in this step. Adopting is a separate, approved action.
- Stars can be bought. A repo with many stars but few forks, no issues and one
  commit is suspect.

## Common issues

- `gh search` returns nothing: the terms are too specific. Drop one term.
- Only old repos: fine to adapt the idea, not to install unmaintained code.
- `gh` auth error or 404 on a repo he owns: another session may have switched
  the active gh account (`gh auth status`).
