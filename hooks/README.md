---
title: Hooks
parent: Resources
nav_order: 3
permalink: /hooks/
---
# Claude Code Hooks

Hooks are shell scripts that run automatically at defined points during a Claude Code session. They enforce consistency without requiring manual review.

## How Hooks Work

Claude Code supports these hook points:

| Hook Point | When It Runs |
|------------|-------------|
| `PreToolUse` | Before Claude uses a tool (Edit, Write, Bash, etc.) |
| `PostToolUse` | After Claude uses a tool |
| `Notification` | When Claude sends a notification |
| `Stop` | When Claude finishes a response |
| `SessionStart` | When a new session begins |
| `UserPromptSubmit` | When you submit a prompt |
| `PreCompact` | Before context is compacted |

## Setting Up Hooks

### 1. Create the hook script

Place your hook scripts in `~/.claude/hooks/` (global) or `.claude/hooks/` (project-local):

```bash
mkdir -p ~/.claude/hooks
cp hooks/*.sh hooks/*.py ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh ~/.claude/hooks/*.py
```


### 2. Register in settings.json

A sanitised copy of the author's live wiring (only the scripts actually registered) is in [`examples/settings.hooks.json`](../examples/settings.hooks.json). Copy the `hooks` block into `~/.claude/settings.json` and delete the entries for scripts you do not want. A minimal example:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/firewall.sh", "timeout": 5 }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/ts-check.sh", "timeout": 60 }
        ]
      }
    ]
  }
}
```

Hook points not in the table above that the example wiring also uses: `PreCompact`, `UserPromptSubmit`, `PermissionRequest`, `SessionEnd`, `SubagentStop`, `StopFailure`.

### Configuration Options

| Field | Description |
|-------|-------------|
| `matcher` | Regex pattern matching tool names (e.g., `"Edit"`, `"Edit\|Write"`, `""` for all) |
| `type` | Always `"command"` |
| `command` | Path to the hook script, with any flags |
| `timeout` | Maximum execution time in seconds |
| `statusMessage` | Message shown in the spinner while the hook runs |
| `async` | If `true`, hook runs without blocking (fire-and-forget) |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success, continue normally |
| 1 | Warning, show output but continue |
| 2 | Error, block the operation and show output |

## Included Hooks

> Many of these depend on the author's other tooling (scripts under `~/.claude/scripts`, state directories, a Codex or gateway CLI, tmux, a notes vault, particular skills). Treat them as examples to read and adapt, not drop-in installs. Check each script's header comment for its inputs and bypass switch.

### Safety and guards

Block or warn before something irreversible, leaky or out of scope happens.

| Script | Event (matcher) | What it does |
|--------|-----------------|--------------|
| `firewall.sh` | PreToolUse (Bash) | Deny gate for irreversible or destructive commands. Fires in every permission mode. |
| `protect-paths.sh` | PreToolUse (Edit|Write) | Blocks edits to protected paths such as env files, lockfiles and credentials. |
| `secret-scanner.py` | PreToolUse (Edit|Write|MultiEdit|NotebookEdit), PostToolUse (Read|Bash|Grep|WebFetch) | Scans content about to be written, and tool output already read, for secrets. Exit 2 blocks or flags. |
| `paste-guard.py` | UserPromptSubmit | DLP gate on what you paste: blocks prompts with credentials, PII or images and puts a sanitised copy on the clipboard. |
| `env-guard.sh` | PreToolUse (Bash) | Blocks committing `.env` files or diffs containing secret patterns. |
| `pre-commit-guard.sh` | PreToolUse (Bash) | Blocks `git commit` when staged code has `console.log`, `console.debug` or `debugger`. |
| `commit-message-check.sh` | PreToolUse (Bash) | Enforces conventional commit message prefixes on `git commit`. |
| `research-only-guard.sh` | PreToolUse (Edit|Write|NotebookEdit and Bash) | While a `research-only.flag` sentinel exists, blocks edits and state-mutating shell commands. |
| `run-referee-guard.sh` | PreToolUse (all tools) | Enforcement half of a run watchdog: blocks tool calls in a session the watchdog has paused or killed. |
| `branch-guard.sh` | PreToolUse (Edit|Write|MultiEdit|NotebookEdit|Bash) | Prints the live branch, dirty state and any other session in the same checkout before editing. |
| `require-agent-model.sh` | PreToolUse (Agent|Task) | Blocks subagent spawns that carry no explicit `model`. |
| `no-new-dep.sh` | PreToolUse (Edit|Write) | Warns when a new dependency name is about to be added to a `package.json`. |
| `test-no-new-dep.sh` | manual | Assertion checklist for `no-new-dep.sh`; run it before and after changing that hook. |
| `hook-edit-smoke.sh` | PostToolUse (Edit|Write) | When a hook script is edited, runs the hooks smoke test and surfaces failures in the same turn. |
| `prose-guard.sh` | PostToolUse (Edit|Write|MultiEdit) | Flags em and en dashes in prose files at the moment they are written. |
| `audit-log.sh` | UserPromptSubmit (optional) | Appends every user prompt to a compliance log. |

### Quality gates

Typecheck, lint, format, test and plan checks around edits, commits and stops.

| Script | Event (matcher) | What it does |
|--------|-----------------|--------------|
| `ts-check.sh` | PostToolUse (Edit|Write) | Runs `tsc --noEmit` after a TypeScript file is edited. |
| `build-check.sh` | PostToolUse (Edit|Write) | Runs a TypeScript build with OOM escalation after `.ts`/`.tsx` edits. |
| `lint-check.sh` | PostToolUse (Edit|Write) | Runs ESLint when a JS or TS file was edited. |
| `format-check.sh` | PostToolUse (Edit|Write) | Warns (exit 1) when an edited file fails Prettier. |
| `test-on-save.sh` | PostToolUse (Edit|Write) | Finds and runs the test file matching an edited source file. |
| `tdd-gate.sh` | PreToolUse (Edit|Write) | Warns, or blocks with `TDD_GATE_BLOCK=1`, when editing production code that has no matching test. |
| `plan-gate.sh` | PreToolUse (Edit|Write) | Warns when source is edited with no recent plan or spec on disk. |
| `pre-commit-verify.sh` | PreToolUse (Bash) | Blocks `git commit` when the repo's verification bundle fails. |
| `precommit-format.sh` | PreToolUse (Bash) | On `git commit`, normalises CRLF to LF on staged text files and runs the formatter. Opt-out. |
| `verify-gate.sh` | PreToolUse (Edit|Write) with `--auto-arm`, Stop | Arms a typecheck baseline on first edit, then blocks the stop if typecheck or tests regressed. |
| `auto-simplify.sh` | PreToolUse (Bash) | On `git commit`, sends the staged diff to a Codex review and blocks on P1 findings. |
| `codex-prepush-review.sh` | PreToolUse (Bash) | On `git push`, sends HEAD vs the main branch to a Codex review and blocks on P1 findings. |
| `matcha-review.sh` | Stop | Sends the working diff to an alternate gateway for a background, read-only second review. |
| `matcha-offload-gate.sh` | PreToolUse (Agent|Task) | When the subscription window is nearly spent, steers cheap mechanical subagent work to the gateway. |

### Evidence recorder and gate pairs

A passive PostToolUse recorder logs that something really happened; a PreToolUse gate refuses to proceed without that record.

| Script | Event (matcher) | What it does |
|--------|-----------------|--------------|
| `evidence-recorder.sh` | PostToolUse (Bash) | Records verification runs (tests, typecheck, builds) as they happen. |
| `mutation-proof-gate.sh` | PreToolUse (Bash) | Uses the recorded evidence to require new tests to be shown failing before they count. |
| `probe-recorder.sh` | PostToolUse (Bash|WebFetch|chrome navigate) | Records that an external service answered at least once. |
| `probe-gate.sh` | PreToolUse (Edit|Write|MultiEdit) | Blocks writes that build around an external dependency until a probe has succeeded. |
| `ui-state-recorder.sh` | PostToolUse (Bash and chrome page tools) | Records the live theme or state queried from the running UI. |
| `ui-state-gate.sh` | PreToolUse (Edit|Write|MultiEdit) | Blocks the first style edit of a visual QA session until a real state query has returned. |
| `leg-scope.sh` | UserPromptSubmit `--arm`, PostToolUse (Bash) `--record`, PreToolUse (Edit|Write|MultiEdit) `--gate` | Forces a continuation session to state its own finish line before its first edit. |

### Session lifecycle and handoff

Preserve and restore state across compaction, stops and fresh sessions.

| Script | Event (matcher) | What it does |
|--------|-----------------|--------------|
| `session-start-check.sh` | SessionStart | Validates the environment and checks common dev ports when a session begins. |
| `sessionstart-handoff.sh` | SessionStart | Re-injects the last handoff so a fresh session resumes cleanly. |
| `session-load-guard.sh` | SessionStart (startup) | Warns when too many sessions are live or one has run past its time cap. Reports only, never kills. |
| `tmux-map.sh` | SessionStart | Records where a session physically lives (tmux pane). |
| `tmux-name-sync.sh` | UserPromptSubmit | Keeps the tmux session name matching the Claude session name. |
| `precompact-handoff.sh` | PreCompact | Saves state before compaction discards it. |
| `stop-handoff.sh` | Stop | Writes a compact, deterministic where-I-left-off handoff. |
| `reboot-stamp.sh` | PostToolUse (Edit|Write) | Guarantees an identity block on handoff files and drops a same-terminal claim ticket. |
| `push-sweep.sh` | Stop | Surfaces unpushed commits before they strand. |
| `daydream.sh` | Stop | When idle, occasionally spawns a detached headless pass that recombines memory notes into ideas. |
| `daydream-surface.sh` | SessionStart | Surfaces the daydreams generated while you were away. |
| `daydream-engine-prompt.md` | used by `daydream.sh` | Prompt text for the daydream pass (not a hook). |
| `HANDOFF.md` | reference | Notes on the handoff format shared by the lifecycle hooks (not a hook). |
| `open-question.py` | UserPromptSubmit `--prompt`, Stop `--stop` | Pins the question you asked so bundled work cannot bury it. |
| `vault-recall.py` | UserPromptSubmit | Surfaces relevant notes from a local notes vault by matching prompt keywords. Never blocks. |

### Prompt nudges and reply shape

Inject a short rule next to the request so it binds, or check the reply shape at stop.

| Script | Event (matcher) | What it does |
|--------|-----------------|--------------|
| `answer-shape-nudge.sh` | UserPromptSubmit | Reinforces three answer-shape rules a brevity mode does not cover. |
| `register-gate.py` | UserPromptSubmit `--prompt`, Stop | Blocks a turn whose reply breaks the register rules. |
| `status-shape-gate.sh` | Stop | Blocks status replies that are not did, doing, need. |
| `canary.sh` | UserPromptSubmit | Asks for a per-reply traffic-light status and a per-project canary on long replies. |
| `babysitting-nudge.sh` | UserPromptSubmit | Nudges toward autonomy loops when a prompt looks like babysitting. |
| `context-threshold-nudge.sh` | UserPromptSubmit | Nudges a handoff when context use crosses a threshold. |
| `factual-guardrail-nudge.sh` | UserPromptSubmit | Nudges cite-or-omit on factual or research-shaped prompts. |
| `correction-detect.sh` | UserPromptSubmit | Catches plain-English corrections so a lesson is captured without a marker. |
| `feedback-marker.sh` | UserPromptSubmit | Handles `:)` and `:(` feedback markers. |
| `ui-state-nudge.sh` | UserPromptSubmit | Reminds Claude to assert the live theme or state before judging a UI. |
| `shadcn-nudge.sh` | UserPromptSubmit | Nudges toward real shadcn components on UI work instead of hand-rolled primitives. |
| `sofa-nudge.sh` | UserPromptSubmit | Reminds Claude to use the connected Q and A tools for coding questions. |
| `search-first-nudge.sh` | PreToolUse (Bash) | Advisory: look for existing code or tools before building from scratch. |
| `chrome-ref-first.sh` | PreToolUse (chrome computer, read_page, find) | Advisory: prefer element references over pixel coordinates. |
| `auto-mode.py` | UserPromptSubmit `--prompt`, PreToolUse (AskUserQuestion) `--gate`, Stop `--stop` | When auto mode is on, Claude decides instead of asking. |
| `tldr-mode.py` | skill frontmatter hook (once) | Latches a plain-English tldr register for the rest of the session. |
| `matcha-surface.sh` | UserPromptSubmit | Delivers finished background reviews and warns when the subscription window is nearly spent. |

### PR gates

Make a pull request earn its claims before it is opened or updated.

| Script | Event (matcher) | What it does |
|--------|-----------------|--------------|
| `pr-claim-gate.sh` | PreToolUse (Bash) | Every measurement in a PR body must come from a run that actually happened. |
| `pr-closing-keyword-guard.sh` | PreToolUse (Bash) | Stops a PR auto-closing an issue it has not finished. |
| `pr-prior-round-gate.sh` | PreToolUse (Bash) | Requires the last review round to be answered before asking for the next. |
| `pr-gate-ack-promote.sh` | PostToolUse (Bash) | Turns a recorded question into a recorded human yes. |

### Fun and notify

Optional extras.

| Script | Event (matcher) | What it does |
|--------|-----------------|--------------|
| `notify-local-tts.sh` | Stop (async) | Spoken completion notice via a local voice, falling back to macOS `say`. Reads `notification.conf`. |
| `notification.conf` | config | Settings for the TTS notifier (not a hook). |
| `play-tts.sh` | called by notifiers | Small TTS wrapper with a mute switch. |
| `coin-rain.sh` | Stop | Earns coins from tokens spent in the turn and shows them in a separate terminal window. |
| `coin-window.sh` | launched by `coin-rain.sh` | Long-running watcher that redraws the coin-rain display. |
| `coin-bank.py` | used by the coin scripts | Atomic read, modify, write helper for the coin state file. |

## Creating Custom Hooks

Hooks receive JSON on stdin with the tool input. Parse it with `jq`:

```bash
#!/bin/bash
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Your logic here
if some_check_fails "$FILE_PATH"; then
  echo "Error: check failed for $FILE_PATH" >&2
  exit 2
fi

exit 0
```

**Tips:**
- Always handle missing fields gracefully (`// empty` in jq)
- Exit early for irrelevant file types to keep hooks fast
- Use `>&2` for error output (stdout is captured differently)
- Test manually: `echo '{"tool_input":{"file_path":"test.ts"}}' | ./your-hook.sh`
