---
title: RTK (Rust Token Killer)
nav_order: 9
parent: Advanced
---
# RTK (Rust Token Killer)

A small CLI that sits between Claude and the shell and trims command output before it reaches the
context window. `git status`, `grep`, test runs, `ls`, `gh` and friends come back grouped,
deduplicated and truncated. Source: [rtk-ai/rtk](https://github.com/rtk-ai/rtk) (Apache 2.0).

```bash
brew install rtk          # or: cargo install rtk
rtk init --global         # wires the Claude Code hook and drops an RTK.md into ~/.claude
```

## How it fires

`rtk init --global` adds one `PreToolUse` hook on `Bash` that runs `rtk hook claude`. The hook
rewrites a known command to its `rtk` equivalent (`grep` becomes `rtk grep`, `git log` becomes
`rtk git log`) before it runs. Nothing changes in how you or the model type commands. Commands it
does not know pass through untouched.

The global `RTK.md` it installs is four lines, @-imported from `CLAUDE.md`, so the model knows the
three commands that are never rewritten:

| Command | What it is for |
|---|---|
| `rtk gain` | Savings so far, overall and per command |
| `rtk discover` | Commands you ran that RTK could have filtered but did not |
| `rtk proxy <cmd>` | Run a command raw, no filtering. Use it when you are debugging and need every byte |

## What it saves

On the author's machine after roughly 240,000 commands: 1.33 billion tokens saved, 80.8% of the
output that would otherwise have entered context. `rtk grep` alone accounts for about half.

```bash
rtk gain               # your own numbers
rtk cc-economics       # spend (via ccusage) against what RTK saved
```

## Where it bites

1. **Truncation hides the line you wanted.** `rtk grep` caps line length and result count. When a
   search seems to miss something, re-run it with `rtk proxy grep ...` before concluding it is not
   there.
2. **Flags it does not understand.** Some native flags are dropped with a warning (`rtk find`
   ignores `-prune`, for example). The warning is on stderr; read it.
3. **Name collision.** There is an unrelated Rust crate also called `rtk`. If `rtk gain` is
   "command not found", you installed the wrong one.
4. **Hooks that parse output.** Your own hooks see the filtered output too. A hook that greps test
   output for a pass count should call the underlying tool via `rtk proxy`.

## Turning it off

Remove the `rtk hook claude` entry from `settings.json`, or prefix single commands with
`rtk proxy`. Uninstalling the binary without removing the hook will break every Bash call.
