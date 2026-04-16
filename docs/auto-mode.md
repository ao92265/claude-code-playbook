---
title: Auto Mode
nav_order: 5
parent: "Patterns & Techniques"
---
# Auto Mode: AI-Powered Permission Triage

Claude Code stops to ask permission before running shell commands, writing files, and calling external services. In a productive session, you can hit 40+ permission prompts. Developers learn to approve them without reading.

This rubber-stamp pattern is not a quirk — it's a documented vulnerability.

---

## The Problem

A 2,243-developer survey found that after the first 10 minutes of a session, the majority of developers approve permission prompts without reviewing them. They've mentally classified "Claude asking permission" as noise.

Security researchers proved this is exploitable. A malicious package comment, a crafted test fixture, or a poisoned file in the repo can contain a prompt injection that triggers a shell command. The developer approves it reflexively.

The `security-guidance` hook — which fires on file writes — doesn't cover shell execution. A prompt injection that reaches `Bash` skips the hook entirely. The human is the last line of defense, and the human has stopped reading.

---

## How Auto Mode Works

Auto Mode replaces the human rubber-stamp with an AI classifier. Before each tool call is approved, a fast model evaluates it against a risk policy:

- **Safe**: Read-only operations, writes to expected paths, known-safe commands (`npm test`, `tsc --noEmit`, `git status`)
- **Review**: Operations outside the expected scope, writes to sensitive paths, commands with unfamiliar flags
- **Block**: Shell commands that exfiltrate data, write outside the project directory, modify git history, or touch secrets files

The classifier runs in milliseconds. Low-risk operations proceed without interrupting you. High-risk operations surface for human review — but now you're only seeing the 1-in-20 that actually deserve attention.

### Configuration

Auto Mode is configured in your project's `.claude/settings.json`:

```json
{
  "autoMode": {
    "enabled": true,
    "policy": "balanced",
    "blockPatterns": [
      "curl * | sh",
      "wget * | bash",
      "rm -rf /",
      "git push --force"
    ],
    "reviewPaths": [
      "~/.ssh/**",
      "~/.aws/**",
      ".env*",
      "*.pem",
      "*.key"
    ],
    "safeCommands": [
      "npm test",
      "npm run build",
      "tsc --noEmit",
      "git status",
      "git diff"
    ]
  }
}
```

**Policy options:**

| Policy | Behavior |
|--------|---------|
| `permissive` | Block only obvious exploits; approve most things |
| `balanced` | Block exploits + review sensitive paths; approve routine dev operations |
| `strict` | Review all shell execution; block anything outside project directory |

---

## Risk Mitigation Without Auto Mode

If Auto Mode isn't available or you're not ready to enable it, use these mitigations in order of impact.

### 1. Restrict shell access at the session level

Start sessions with `--disallowedTools Bash` when you're doing code review, planning, or file editing — tasks that don't require shell execution:

```bash
claude --disallowedTools Bash
```

This eliminates the shell injection surface entirely for read-heavy sessions.

### 2. Use per-tool allow-lists

In `.claude/settings.json`, define which tools are allowed for your project:

```json
{
  "allowedTools": [
    "Read",
    "Write",
    "Edit",
    "Bash(npm test)",
    "Bash(npm run build)",
    "Bash(tsc --noEmit)",
    "Bash(git status)",
    "Bash(git diff)"
  ]
}
```

This is an explicit allowlist — anything not listed requires a prompt. You're approving deviations from your expected workflow, not approving everything.

### 3. Run in a Docker sandbox

For untrusted codebases or security-sensitive work, run Claude Code inside a container with limited filesystem access:

```bash
docker run --rm -it \
  -v $(pwd):/workspace \
  -w /workspace \
  --network none \
  node:20 \
  claude
```

`--network none` prevents exfiltration. The container filesystem boundary limits write access. The cost is that Claude can't install packages or reach external APIs.

### 4. Audit `.claude/settings.json` regularly

The settings file is a high-value target. A prompt injection that can write to `.claude/settings.json` can expand its own permissions. Add it to your review checklist:

```bash
# Check for unexpected permission grants after a session
git diff .claude/settings.json
```

---

## Security Considerations

**Prompt injection via repo content.** Any file Claude reads is a potential injection vector: `README.md`, `CHANGELOG.md`, test fixtures, package names, code comments. Keep this in mind when working on repos you didn't create.

**The `security-guidance` hook gap.** The built-in hook fires on file writes. It does not fire on shell execution. Do not assume the hook makes your sessions safe — it covers one attack surface, not all of them.

**Shared team settings.** If `.claude/settings.json` is committed to your repo, every developer on the team gets the same permission policy. This is a feature (consistency) but also a risk (a single PR can weaken everyone's security posture). Review settings changes with the same rigor as security-critical code.

**Auto Mode is not a guarantee.** The classifier can be fooled. Treat it as a force multiplier for human attention — it surfaces the suspicious calls so a human can make an informed decision. It doesn't replace judgment.

---

## Recent Enhancements (v2.1.81–2.1.89)

### PermissionDenied Hook (v2.1.89)

A new hook event that fires **after** Auto Mode's classifier denies a tool call. Return `{retry: true}` to tell the model it can retry with a different approach. This creates a feedback loop where denied operations don't just fail silently — the agent can adapt its strategy.

```json
{
  "hooks": {
    "PermissionDenied": [{
      "type": "command",
      "command": "echo '{\"retry\": true}'"
    }]
  }
}
```

### Deferred Permission Decisions (v2.1.89)

PreToolUse hooks can now return `"defer"` — the headless session pauses at the tool call and can be resumed later with `-p --resume` to have the hook re-evaluate. This enables **asynchronous human-in-the-loop workflows** where an external system (Slack bot, approval dashboard, CI gate) decides whether to allow a tool call on its own timeline.

### Permission Relay via Channels (v2.1.81)

When using Channels (Telegram/Discord), tool approval prompts are forwarded to your phone. Reply `yes <id>` or `no <id>` to approve or deny. This means Auto Mode + Channels gives you remote permission management without `--dangerously-skip-permissions`. See [channels.md](channels.md#permission-relay) for setup.

### Denied Command Visibility (v2.1.89)

Auto Mode denied commands now show a notification and appear in `/permissions` → Recent tab where you can retry with `r`. Previously denied commands were silent and required restarting the operation.

---

## Quick Reference

```bash
# Disable shell access for read-only sessions
claude --disallowedTools Bash

# Run in network-isolated Docker sandbox
docker run --rm -it -v $(pwd):/workspace -w /workspace --network none node:20 claude

# Check for unexpected settings changes after a session
git diff .claude/settings.json
```
