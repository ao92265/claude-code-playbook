# Core Rules
<!-- @-imported by CLAUDE.md. In backup.sh allowlist. Test for every rule: "would Claude do this anyway?" -->

## Session Hygiene
- One task per session. At ~50% context write a `/reboot` handoff, then `/clear` and resume from it. Switching tasks means `/clear` first.
- 4h cap, enforced as a PAUSE not a kill: run-referee.py meters every session and pauses past 4h (a false kill costs more than a missed one, so it never kills on age alone; it does kill on token budget and API-error loops). Surface a paused session to the user and let him decide. Never kill a session yourself.
- No full-file dumps. Extract the 20 relevant lines. Also here: `/demo2skill` (record a demo, get a skill) and `/automations` (scheduled jobs).
- Auto-compact MUST keep: task constraints, API and schema changes with rationale, exact error messages and their fixes, the modified-file list, one line per failed approach. Drop tool output bodies and prose.

## Model & Subagent Economics
- Main loop runs the top tier; subagents inherit it. Never name a model or price here, it rots. Check live via the `claude-api` skill.
- Routing (require-agent-model.sh blocks a spawn with no `model=`): haiku for search and extraction, sonnet for mechanical bulk edits (never at max effort: it costs more than the top tier there and scores worse than xhigh), top tier only for judgment (architecture, review, debugging).
- Cap subagent output: every prompt says "verdict plus max 5 bullets, no full body". Max 3 parallel, 2 for reviewer or Explore.
- Direct work beats delegation when it fits in main context. Cost watch: `~/.claude/scripts/observatory-weekly.sh`.

## Long-Running / Autonomous Work
- Objectives beat task lists: say what done looks like and how to verify, then let it run.
- A continuation session states its OWN finish line before editing, distinct from the project's (`leg-done: <one line>`, leg-scope.sh blocks until it exists). Continuation is 59% of sessions and inheriting the project's goal is what makes them end on context exhaustion instead of completion.
- Proactively route objective-shaped work (clear done-state, verifiable, more than 3 iterations) to a ready-to-paste `/loop` or `/goal`. One-shot tasks: just do them.
- Any autonomous loop self-cancels on done and verified, or after 15 min stuck.
- Three strikes: `/rewind` if the context is freshly polluted, otherwise `/clear` and rewrite the prompt.

## Definition of Done (and the gates around it)
1. Enumerate every item from the original prompt, paste the verify command and exit code for each, flag anything deferred.
2. Evidence before any done claim: run the checks and show the exit codes. Superpowers verification-before-completion owns this loop; `/done` runs the full bundle when you want it in one command. verify-gate.sh still blocks the stop on a typecheck regression regardless.
3. Escalation is on request, not mandatory: `/codex:rescue` for a second pass, `/multiask` for high stakes.
- No "fixed" without observed proof: exercise the change and watch it behave (the `run` skill drives the real app). Green tests are not evidence that it works.
- Two failed fix passes means hand it to Codex rather than grinding on; commit hooks are skipped for latency.
- Deletion budget: any feature spanning 3 or more sessions gets one `ai-slop-cleaner` pass before done. Prefer replacing over appending. Shell help: `gh copilot suggest`.

## Repo & Workflow (non-derivable)
- Multi-PR work goes in a worktree, or an explicit switch that you verify.
- Schema-affecting work: surface it at planning time and batch the authorisation. protect-paths.sh blocks the edits themselves, including .env files, lockfiles and credentials.
- Confirm PR and commit authors with the `gh` CLI before naming anyone in a review or reply.
- Before drafting a reply, confirm recipient role, technical level, tone and the action wanted. Unspecified means ask.

## Verify Against Live State
- PRs: re-fetch live state before claiming done or no-changes-needed. CHANGES_REQUESTED is sticky until the reviewer clears it, and never auto-dismiss theirs: summarise and wait.
- UI: never certify a fix from your own screenshots. Find the cause in source, then have the user confirm in his browser.
- "RESEARCH-ONLY" means findings only, enforced by research-only-guard.sh.

## Standards and Maintenance
- Route through these, do not improvise: `/done` for done claims · `/demo-qa` and `/visual-verdict` for UI QA · `/granola-to-obsidian` for meetings · `/expenses-system-expenses` · `/morning` for a recap · `/reboot` for bloated context · `/prdforge` for plans and PRDs (`--handoff` for cheap-model execution) · `/anti-ai-prose` on any publishable draft, never on code or commits.
- Rule budget: under 150 lines, counted as CLAUDE.md plus the files it @-imports, blanks and HTML comments excluded (`scripts/rule-budget.sh`). Files not @-imported do not count and do not load. A rule ignored for 3 sessions gets deleted or hooked. Reference sections by name, never line number.
- Always means a hook, usually means a skill (`/skill-authoring`). Weekly `maintenance.sh`, and `hooks-smoke-test.sh` after editing any hook.
- Register and answer shape are hook-enforced and injected every prompt. Edit the hook, not this file.
