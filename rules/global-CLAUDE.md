# Working rules

<autonomy>
`/auto` decides judgment calls instead of asking you (hook-enforced, per session). `/auto
away` (alias `/afk`) adds the unattended ladder and loop. `/carryon` one next action, stops
on a decision. `/oneshot` idea to green PR. Everything else native: `/loop`, `/goal`,
Workflow, agent teams. Say "afk" to start it, "deslop" for ai-slop-cleaner.
</autonomy>

<superpowers>
Default process layer, here and in Codex. Let it lead: brainstorming before creative work,
TDD, systematic-debugging, requesting-code-review, verification-before-completion. Follow
the skill it picks, do not route around it. Announce one once when it fires, not every
turn. The user's skills are on demand only: `/prdforge` for a written PRD instead of a
conversation, `/done` for a full gate run, `/multiask` and `/codex:rescue` to escalate.
</superpowers>

<agents>
Bare: architect, code-reviewer, critic, debugger, executor, planner, qa-tester,
security-reviewer, verifier, Explore. Delegate multi-file work, refactors, debugging,
reviews, planning, research. Do trivial ops and single commands yourself.
</agents>

<failure_mode_guards>
Need a decision from the user? AskUserQuestion, one question, 2 to 4 options. Prose only for
free-form answers.
Placeholder TODOs, `test.skip`, `.only`, stub tests and unimplemented branches are
blockers, not evidence. Check changed files for them before claiming done.
</failure_mode_guards>

<state_and_hooks>
Per-project agent state (handoffs, plans, research) lives in `.omc/`. Historical name, live
directory, the HUD reads it. `CLAUDE_SKIP_HOOKS` disables one hook for one command.
</state_and_hooks>

<!-- Custom global config lives in the @-imported files below, one topic per file. -->

@core-rules.md
@RTK.md
@factual-guardrails.md
@workflow-rules.md
@design-rules.md

<!-- CODEGRAPH_START -->
## CodeGraph

In a repo with a `.codegraph/` directory, run `codegraph explore "<symbols or question>"`
before grep or reading files. It returns the relevant source plus the call paths between
symbols, including dispatch hops grep cannot follow. No `.codegraph/` directory means skip
it entirely; indexing is the user's call.
<!-- CODEGRAPH_END -->
