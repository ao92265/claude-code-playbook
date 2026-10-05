# Workflow Rules
<!-- @-imported by CLAUDE.md. In backup.sh allowlist. -->

## Bash
No commands that wait on stdin or open a pager (firewall.sh blocks them). Pick the non-interactive flag upfront: `git commit -m` or `--no-edit`, `git add -A` or explicit paths, `init -y`, heredocs instead of an editor.

## PR Merge Authorisation
- Autonomous: rebase onto main; merge once CI is green, it is approved, and no CHANGES_REQUESTED is live; dismiss a stale review of your own or a bot's whose findings are already fixed.
- Ask first: force-push to main or a shared branch, writing to a shared or prod repo, dismissing a live reviewer's CHANGES_REQUESTED (sticky until they clear it, so summarise and wait).
- Push-verify: confirm the current branch matches the target PR branch, then check the push exited 0 and was not a silent no-op or rejection before claiming it landed. Nothing else checks this at push time; the Codex review only fires at stop time, after the push.

## Branch & Worktree Safety
- Assert branch and worktree at the FIRST edit, not at push. branch-guard.sh prints the live branch, dirty state and any other session sitting in the same checkout. Read it and do not edit past a mismatch. A whole frontend once got built on the wrong branch; push-time checks are too late.
- Multi-PR or shared-tree work goes in an isolated worktree off `origin/main`, never the shared checkout.

## First-Pass Quality Gates
- Test first on any 2-file edit (tdd-gate.sh warns): a failing test or an explicit assertion checklist before you edit. Red means your assertion failed, not a missing module or a broken runner.
- Probe first on external dependencies. This is a blocking gate, not advice. Corporate SSO, OAuth, third-party pairing, MDM, Outlook, SharePoint, WhatsApp, TikTok, LinkedIn: run the auth or feasibility probe AND name the fallback before building anything around it. probe-gate.sh blocks the write until the service has answered once. Every one of those was a 5-minute probe and a dead-ended session.
- Budgeted autonomous runs: emit a `/reboot` handoff (state, next step, verify command) at about 20 tool calls or 50% context, whichever comes first. Proactively, not at the wall.
- Binary or byte-exact files (signatures, PNGs, exact configs): write binary, no newline normalisation, no trailing LF. The commit hook only fixes text files.
- No regex for parsing code or nested structured text (source, JSON, HTML, YAML, SQL). Use the language's parser or AST library, tree-sitter, or a generated grammar (ANTLR). Regex stays fine for flat, single-line patterns.

## Codex Companion Routing
- Codex is an independent lane, not a second narrator. Send it a bounded slice of substantial implementation, a second pass, or a hard root-cause hunt. Skip lookups, prose and anything Claude finishes quickly.
- Escalate after ONE failed diagnosis: a fresh read-only rescue request with the shortest decisive error, the scope, the expected behaviour and an evidence-first output contract.
- Order when a Codex review is wanted: verify locally first (Superpowers verification, or `/done` for the full bundle), then send it. A failed local gate goes back to implementation before review.
- Adversarial review is for decisions (architecture, public API, data model, security, prod, irreversible). Routine diffs get the normal review.
- Keep review and repair separate. Present findings by severity and let the user pick. After a repair, re-verify and get a fresh review.
- Run it in the background and keep working; collect with status and result.

## Own Response Length
- Split a long deliverable across turns rather than truncating. The subagent output cap applies to subagents, not to your main reply.
- Loop and autonomous status messages follow the same verdict-plus-5-bullets cap. Full detail goes to a file, not the transcript.
