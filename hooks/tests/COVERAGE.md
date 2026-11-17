# Hook test coverage

Every hook script in `hooks/` has a behaviour test here, or a one-line reason why it cannot be tested offline.

Each test was checked against a deliberate break: the hook body was replaced with an early exit, and the test had to fail. Run them all with `bash hooks/tests/run-all.sh`.

## Totals

- Hook scripts: 84 (the README and CI count 85 files in `hooks/`, because they also count `test-no-new-dep.sh`, an old checklist that is not a hook)
- Tested: 82
- Untestable offline: 2

## Untestable offline

| Hook | Reason |
|------|--------|
| coin-window.sh | An endless watcher loop that runs in its own Terminal window and only redraws the screen. It has no input or output to assert on. |
| daydream.sh | Spawns a detached headless `claude` run that needs a keychain login token. Testing it means a real model call. |

## Tested

Some tests skip themselves where a tool is missing: the three zsh hooks skip where zsh is not installed (the CI job installs zsh, so they run there), and `test-commit-message-check.sh` skips where grep has no PCRE support (stock macOS).

| Hook | Test file |
|------|-----------|
| answer-shape-nudge.sh | test-answer-shape-nudge.sh |
| audit-log.sh | test-audit-log.sh |
| auto-mode.py | test-auto-mode.sh |
| auto-simplify.sh | test-auto-simplify.sh |
| babysitting-nudge.sh | test-babysitting-nudge.sh |
| branch-guard.sh | test-branch-guard.sh |
| build-check.sh | test-edit-checkers.sh |
| canary.sh | test-canary.sh |
| chrome-ref-first.sh | test-chrome-ref-first.sh |
| codex-prepush-review.sh | test-codex-prepush-review.sh |
| coin-bank.py | test-coin-bank.sh, test-coin-rain.sh |
| coin-rain.sh | test-coin-rain.sh |
| commit-message-check.sh | test-commit-message-check.sh (skipped where grep has no PCRE) |
| context-threshold-nudge.sh | test-context-threshold-nudge.sh |
| correction-detect.sh | test-correction-detect.sh |
| daydream-surface.sh | test-daydream-surface.sh |
| dotnet-build.sh | test-dotnet-build.sh |
| dotnet-msbuild-guard.sh | test-dotnet-msbuild-guard.sh |
| env-guard.sh | test-env-guard.sh |
| evidence-recorder.sh | test-evidence-recorder.sh |
| explainer-gate.py | test-explainer-gate.sh |
| factual-guardrail-nudge.sh | test-factual-guardrail-nudge.sh |
| feedback-marker.sh | test-feedback-marker.sh |
| firewall.sh | test-firewall.sh |
| format-check.sh | test-edit-checkers.sh |
| goal-pin.py | test-goal-pin.sh |
| hook-edit-smoke.sh | test-hook-edit-smoke.sh |
| leg-scope.sh | test-leg-scope.sh |
| lint-check.sh | test-edit-checkers.sh |
| matcha-offload-gate.sh | test-matcha-offload-gate.sh (zsh; skipped where zsh is missing) |
| matcha-review.sh | test-matcha-review.sh (zsh; skipped where zsh is missing) |
| matcha-surface.sh | test-matcha-surface.sh (zsh; skipped where zsh is missing) |
| mutation-proof-gate.sh | test-mutation-proof-gate.sh |
| no-new-dep.sh | test-no-new-dep.sh |
| notify-local-tts.sh | test-notify-local-tts.sh |
| open-question.py | test-open-question.sh |
| paste-guard.py | test-paste-guard.sh |
| plan-gate.sh | test-plan-gate.sh |
| play-tts.sh | test-play-tts.sh |
| pr-claim-gate.sh | test-pr-claim-gate.sh |
| pr-closing-keyword-guard.sh | test-pr-closing-keyword-guard.sh |
| pr-gate-ack-promote.sh | test-pr-claim-gate.sh, test-pr-gate-ack-promote.sh |
| pr-prior-round-gate.sh | test-pr-prior-round-gate.sh |
| pre-commit-guard.sh | test-pre-commit-guard.sh |
| pre-commit-verify.sh | test-pre-commit-verify.sh |
| precommit-format.sh | test-precommit-format.sh |
| precompact-handoff.sh | test-precompact-handoff.sh |
| probe-gate.sh | test-probe-gate.sh |
| probe-recorder.sh | test-probe-gate.sh |
| prose-guard.sh | test-prose-guard.sh |
| protect-paths.sh | test-protect-paths.sh |
| push-gate.py | test-push-gate.sh |
| push-sweep.sh | test-push-sweep.sh |
| reboot-stamp.sh | test-reboot-stamp.sh |
| register-gate.py | test-register-gate.sh |
| require-agent-model.sh | test-require-agent-model.sh |
| research-only-guard.sh | test-research-only-guard.sh |
| restate-gate.sh | test-restate-gate.sh |
| run-referee-guard.sh | test-run-referee-guard.sh |
| search-first-nudge.sh | test-search-first-nudge.sh |
| secret-scanner.py | test-secret-scanner.sh |
| session-load-guard.sh | test-session-load-guard.sh |
| session-start-check.sh | test-session-start-check.sh |
| sessionstart-handoff.sh | test-sessionstart-handoff.sh |
| shadcn-nudge.sh | test-shadcn-nudge.sh |
| sofa-nudge.sh | test-sofa-nudge.sh |
| status-shape-gate.sh | test-status-shape-gate.sh |
| stop-handoff.sh | test-sessionstart-handoff.sh, test-stop-handoff.sh |
| tdd-gate.sh | test-tdd-gate.sh |
| test-gate.py | test-test-gate.sh |
| test-on-save.sh | test-test-on-save.sh |
| tldr-mode.py | test-tldr-mode.sh |
| tmux-map.sh | test-tmux-map.sh |
| tmux-name-sync.sh | test-tmux-name-sync.sh |
| ts-check.sh | test-edit-checkers.sh |
| ui-state-gate.sh | test-ui-state-gate.sh |
| ui-state-nudge.sh | test-ui-state-nudge.sh |
| ui-state-recorder.sh | test-ui-state-gate.sh |
| vault-recall.py | test-vault-recall.sh |
| verify-gate.sh | test-verify-gate.sh |
| voice-queue.sh | test-voice-queue.sh |
| worktree-gate.sh | test-worktree-gate.sh |

## Not hooks

These files sit in `hooks/` but are not hook scripts, so they have no test of their own.

| File | What it is |
|------|------------|
| HANDOFF.md, README.md | Documentation |
| daydream-engine-prompt.md | Prompt text read by daydream.sh |
| hooks.json, notification.conf | Configuration |
| test-no-new-dep.sh | An older assertion checklist for no-new-dep.sh, kept as is |
| lib/ | Shared helpers, exercised through the hooks that load them |
