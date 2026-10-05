# Global rules

The author's `~/.claude` rule files, sanitised. `global-CLAUDE.md` is the file that goes at
`~/.claude/CLAUDE.md` (renamed here so it does not load as this repo's project rules). It
@-imports the other five:

| File | Covers |
|---|---|
| `core-rules.md` | Session hygiene, model routing for subagents, long-running work, definition of done |
| `workflow-rules.md` | Non-interactive Bash, PR merge authority, branch and worktree safety, first-pass gates, Codex routing |
| `factual-guardrails.md` | Say "I don't know" rather than guess; cite or omit |
| `design-rules.md` | Where UI work takes its design system from, and how UI fixes get verified |
| `RTK.md` | The four lines [RTK](../docs/rtk.md) needs the model to know |

Budget: under 150 lines across all six, blank lines excluded. A rule ignored for three sessions
becomes a hook or gets deleted. Many lines name skills or hooks from this repo; drop the ones you
do not install.
