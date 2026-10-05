---
name: exec-summary
description: Write a Innovation Team project executive summary (the project-a, project-b, project-c and project-d report format) from a business unit's codebase, following the lab lead's InnovationLab Executive Summary Template, and deliver it as a styled Word document. Counts the repo facts with a script, reads the code for the architecture and features, asks the team only for what a repo cannot know (costs, benchmark, failures, customer value), then runs the template's pre-circulation checklist. Use when someone says "/exec-summary", "project report", "executive summary for project X", "write up the project", "Innovation Team summary", "lab summary", "fill in the exec summary template", or hands over a repo and the InnovationLab template. Do NOT use for a slide deck, a PRD or plan (prdforge), an accelerator or hackathon audit page (accelerator-insights), or a status update.
---

# Executive Summary from a codebase

Produces a 10 to 16 page leadership summary in the InnovationLab template's structure and look. The reader is senior leadership who never followed the build and will decide from this document alone whether the approach is credible and should be repeated.

Files in this skill:
- `references/template-guidance.md`: what every section must carry, ground rules, project-c samples. **Read it before writing a word.**
- `references/skeleton.md`: the markdown to fill. Its format is exactly what the builder parses.
- `scripts/repo_metrics.py`: dated, sourced counts for Part 2, Part 7 and the Appendix.
- `scripts/check_summary.py`: the template's pre-circulation checklist as a script.
- `scripts/build_docx.py`: markdown to .docx in the template's styling (Calibri, teal, sand callouts, leftover placeholders in red).

Scripts are Python 3.9+. The builder needs python-docx: run it with `uv run --with python-docx python3 ...` if it is not installed.

## Workflow

### 1. Pin the inputs
Ask for (or confirm) the repo path, and where the output should go (default: a `exec-summary/` folder next to the repo, never inside someone else's working tree). If the repo is a shallow clone, `git fetch --unshallow` first or the commit figures will be wrong; the metrics script warns when it is.

### 2. Count, do not estimate
```
python3 SKILL_DIR/scripts/repo_metrics.py REPO --out OUT
```
This writes `metrics.json` and `metrics.md` in one run (a large repo takes a couple of minutes, mostly GitHub calls; `--no-github` skips them).
Every value carries its `source`. Quote figures from here, keep the capture date, and never round a count into a different number. Heuristic counts (pages, endpoints, migrations, test cases, the backend and frontend split) say so in their source: spot-check each against the code before quoting, and if your own count differs, quote yours and say how you counted. On non-GitHub remotes the PR figures come back as a note; get them from the host (Azure DevOps: `az repos pr list`) or ask.

**Review rate:** use `independent_human_review` as "human review". A review from the author's own account (usually an agent session) and a bot review are not independent review. If the independent figure is low, say so plainly and describe the real gate, as the template asks.

### 3. Read the code for the prose parts
Part 3 (stack, versions, why each choice), Part 5 (auth, authorisation, audit, data boundaries), Part 6 (features in user order), Part 7 (test layers, lint and type settings, logging). Start from `stack` and `runtime_ai_dependencies` in metrics.json. Use `codegraph explore` if the repo has a `.codegraph/` folder; otherwise delegate the read to an Explore subagent and ask for a verdict plus at most 5 bullets per part. Read the repo's own README, CLAUDE.md or AGENTS.md, plan and decision records first: they usually carry the "why".

If `runtime_ai_dependencies` is empty and the code confirms no model calls, delete the AI Runtime table and the "AI Inside the Product" subsection and say in one sentence that AI was the build engine only.

### 4. Ask for what a repo cannot know
One round of questions to the person running the skill, batched. Do not invent any of these; an unanswered item stays as a `[placeholder]` and shows red in the document.
- Codename, one-line descriptor, scope line, classification.
- Authors: name, role, programme or BU, reporting line or secondment, country.
- Blended rate per developer-month, and the benchmark (traditional team, duration, source: COCOMO II, internal comparable, or the client's estimate).
- Tooling cost per month; any partner or client engineering time to include.
- Start date, completion percentage and the remaining scope.
- What went wrong, with numbers and root cause (at least one).
- Organisational challenges: locations, time zones, holidays, knowledge gaps.
- Customer-side value and any commercial case (figure, horizon, where and when presented).
- First user feedback, and screenshot files for Part 1.

If an earlier summary or decision records in the repo already answer some of these, use them and show the person what you took. `git shortlog` (the `authors` field in metrics.json) gives candidate author names, but confirm who should be named: committers are not always the authors of record.

**Nobody to ask** (a headless or scheduled run): do not stop and do not guess. Fill what the repo states, with its source, leave every other item as its `[placeholder]`, and list them all in the hand-over. The checker will FAIL on those by design; that is the correct result for a draft.

### 5. Write the summary
Copy `references/skeleton.md` to `OUT/summary.md` and fill it section by section, following `template-guidance.md`. Write the Financial Summary last, once every other number is settled. Keep all guidance and sample text out of the output. Put screenshots in OUT and reference them as `![caption](file.png)`.

Then run the `anti-ai-prose` skill over the prose if it is installed: this is a publishable document.

### 6. Check, then build
```
python3 SKILL_DIR/scripts/check_summary.py OUT/summary.md
uv run --with python-docx python3 SKILL_DIR/scripts/build_docx.py OUT/summary.md OUT/Project_CODENAME_Executive_Summary.docx
```
Checks 3, 4 and 8 look for set wording: "per developer-month" with "applied to both scenarios", a named benchmark source, "approximately N percent complete" in Part 2 and "Remaining N Percent" in Part 10. Fix every FAIL that the facts allow. Report the rest to the person, with what is needed to close each. Never claim the document is ready while the checker shows a FAIL; a placeholder left on purpose is fine but must be listed.

### 7. Hand over
Give the .docx path, the checker result, the list of anything still bracketed, and which figures rest on heuristics or on the person's own estimates. Remind them to set the version and to delete nothing else: the checker has already confirmed guidance boxes are gone.

## Common issues

| Symptom | Cause and fix |
|---|---|
| Commit count far too low | Shallow clone. `git fetch --unshallow`, re-run metrics. |
| PR figures missing | Remote is not GitHub, or `gh` is not logged in. `gh auth status`, or use the host's CLI. |
| Review rate looks too high or too low against an earlier write-up | Earlier figure probably counted reviews from the author's own account. Quote the independent figure and explain. |
| Frontend pages = 0 | Naming the heuristic does not know. Count the routes in the router file and quote that instead. |
| `python-docx is not installed` | `uv run --with python-docx python3 ...` or `pip install python-docx`. |
| Builder exits "no \newpage line" | The cover block must end with a line containing only `\newpage`. See skeleton.md. |
| Cover shows red placeholders | Cover fields missing or the author blocks are not separated by blank lines. |
