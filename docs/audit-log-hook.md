---
title: Audit Log Hook
nav_order: 41
parent: Enterprise
---
# Audit Log Hook — Raw Prompt Logging For Compliance

Pattern lifted from [awslabs/aidlc-workflows](https://github.com/awslabs/aidlc-workflows), adapted to a Claude Code `UserPromptSubmit` hook. Every user prompt goes into a timestamped, append-only log. Useful when:

- Regulated environment (SR 11-7, EU AI Act Article 12, ISO 42001) demands traceability of human → AI interactions
- Post-incident forensics on agent behaviour
- Billing/usage attribution inside a team
- Debugging a session that went sideways and you want to replay the exact prompts

---

## What aidlc-workflows Does

aidlc writes to `aidlc-docs/audit.md` with this format:

```markdown
## [Stage Name or Interaction Type]
**Timestamp**: 2026-04-22T14:32:09Z
**User Input**: "Complete raw user input — never summarized"
**AI Response**: "AI's response or action taken"
**Context**: Stage, action, or decision made

---
```

Hard rules from their `core-workflow.md`:

1. Capture user's **complete raw input** — never summarize or paraphrase
2. **Always append**, never overwrite (tool calls that rewrite the whole file cause duplication)
3. ISO 8601 timestamps
4. Include stage context per entry

Their workflow enforces this via a prose rule in `core-workflow.md`. Prose rules drift. A hook is deterministic.

---

## Claude Code Implementation

### 1. The Hook Script

Save as `~/.claude/hooks/audit-log.sh` (global) or `.claude/hooks/audit-log.sh` (per-project):

```bash
#!/usr/bin/env bash
# Append every user prompt to an audit log with ISO 8601 timestamp.
# Triggered by UserPromptSubmit hook. Never blocks input.

set -u

AUDIT_DIR="${CLAUDE_AUDIT_DIR:-${CLAUDE_PROJECT_DIR:-$PWD}/.claude/audit}"
AUDIT_FILE="${AUDIT_DIR}/prompts.md"

mkdir -p "$AUDIT_DIR"

# Hook payload arrives on stdin as JSON
PAYLOAD="$(cat)"

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SESSION_ID="$(printf '%s' "$PAYLOAD" | jq -r '.session_id // "unknown"')"
CWD="$(printf '%s' "$PAYLOAD" | jq -r '.cwd // "unknown"')"
PROMPT="$(printf '%s' "$PAYLOAD" | jq -r '.prompt // ""')"

# Append-only. Never rewrite.
{
  printf '## Prompt\n'
  printf '**Timestamp**: %s\n' "$TIMESTAMP"
  printf '**Session**: `%s`\n' "$SESSION_ID"
  printf '**Cwd**: `%s`\n' "$CWD"
  printf '**User Input**:\n\n```\n%s\n```\n\n---\n\n' "$PROMPT"
} >> "$AUDIT_FILE"

# Exit 0 — never block the prompt
exit 0
```

`chmod +x` it. `jq` required (ships with most dev machines; `brew install jq` on macOS).

### 2. Wire It Up

`.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/audit-log.sh"
          }
        ]
      }
    ]
  }
}
```

Or global at `~/.claude/settings.json` with `command: "$HOME/.claude/hooks/audit-log.sh"`.

### 3. Verify

```bash
# Start a session, type a prompt, then:
cat .claude/audit/prompts.md
```

You should see the exact raw prompt logged with ISO timestamp and session id.

---

## Extending It — Responses, Tool Calls, Redaction

**Log AI responses too** — add a `Stop` hook that appends a `## Response` block. Harder because `Stop` doesn't give you the final assistant text directly; the cleanest path is to tail the session transcript. Skip unless you actually need it.

**Log tool calls** — add `PreToolUse` / `PostToolUse` hooks with `matcher: ".*"` to log tool name and input. Noisier. Good for debugging, bad for daily compliance volume.

**Redaction for secrets** — pipe `$PROMPT` through a redactor before writing. Minimum: mask anything matching `(?i)(password|secret|token|api[_-]?key)\s*[:=]\s*\S+`. See [env-guard.sh](../hooks/env-guard.sh) for the same regex already used in this playbook for pre-commit scans.

**Rotation** — `prompts.md` grows unbounded. Either:
- Rotate daily: change `AUDIT_FILE` to `${AUDIT_DIR}/$(date -u +%Y-%m-%d).md`
- Rotate by size: check `stat -f%z` and roll when > 10MB

**Git-ignore or commit?** — depends. Commit only if prompts never contain secrets and your repo is internal. Default to `.gitignore` + upload to S3 / bucket from CI.

---

## Why Not Just Use Session Logs?

Claude Code keeps session transcripts in `~/.claude/projects/<hash>/`. They contain the prompts. But:

- Path is hash-based, hard to index by project / user / date
- Format is JSONL internal schema, not designed for humans or auditors
- No guarantee of retention policy — harness may compact or delete
- Shared accounts (CI, service users) lose attribution

The hook gives you a **project-local, human-readable, append-only, you-own-it** log. Auditors prefer that.

---

## When Not To Use This

- Solo dev, non-regulated project → skip. Noise.
- Already using OpenTelemetry / [cost-and-observability](cost-and-observability.md) stack → the OTel exporter captures prompts with more structure. Don't double-log.
- Using Managed Agents / Bedrock / Vertex → the platform has its own audit trail. Check what it captures before adding this.

---

## Related

- [regulated-ai.md](regulated-ai.md) — SR 11-7 / EU AI Act Article 12 context
- [enterprise-governance.md](enterprise-governance.md) — Compliance API, managed policies
- [hooks/README.md](../hooks/README.md) — hook authoring patterns
- [harness.md](harness.md) — where hooks sit in the three-layer model
