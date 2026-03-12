---
name: deploy
description: >
  Safe deployment checklist with pre-deploy verification. Use when the user explicitly
  wants to deploy to a live environment. Runs build, tests, and checks before any
  deployment action. Triggers: "deploy", "push to production", "deploy to Azure".

  Do NOT use this skill for: local development, running tests locally, code review,
  staging-only changes, or normal coding sessions. Only trigger when the user explicitly
  intends to deploy.
metadata:
  user-invocable: true
  slash-command: /deploy
  proactive: false
---

# Deploy Workflow

Safe deployment checklist. Runs pre-deploy verification before any deployment action.

## Steps

1. Verify git credentials: `gh auth status` — if failing, STOP and report
2. Run build with OOM prevention: `NODE_OPTIONS='--max-old-space-size=4096' npm run build` — if OOM occurs, retry with 8192
3. Run tests with `npm test` — if any fail, stop and report
4. Check for port conflicts on the target port
5. Verify required environment variables are set (check .env exists, don't expose values)
6. Check git status — warn if there are uncommitted changes
6. Show a summary of what will be deployed (current branch, latest commit, build status)
7. **STOP and ask for explicit confirmation before proceeding with any deployment action**

## Important
- Do NOT push, deploy, or run any deployment commands without explicit user confirmation
- Do NOT proceed past a failed build or test step
- If deploying to Azure, verify the tier supports the required features first
- Always show what branch and commit will be deployed before asking for confirmation
