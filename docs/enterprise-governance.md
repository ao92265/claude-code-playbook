---
title: Governance
nav_order: 1
parent: Enterprise
---
# Enterprise Governance Guide

How to deploy Claude Code across your organisation with proper controls, compliance, and audit trails.

---

## Claude Code Enterprise Plans

| Feature | Max ($100-200/mo) | Team ($30/user/mo) | Enterprise (Custom) |
|:--------|:-----------------:|:------------------:|:-------------------:|
| Claude Code access | Yes | Yes | Yes |
| SSO (SAML/OIDC) | No | No | Yes |
| Managed policies | No | No | Yes |
| Compliance API | No | No | Yes |
| Spend controls | Personal limits | Per-user caps | Per-user + org caps |
| Admin dashboard | No | Basic | Full |
| Seat management | N/A | Self-serve | Self-serve + provisioning |
| Audit logs | No | No | Via Compliance API |
| Data retention controls | No | No | Yes |

**Recommendation:** Start individual developers on Max. Move to Team when 3+ developers are active. Enterprise when you need SSO, compliance, or managed policies.

---

## SSO Setup

Enterprise plans support SAML 2.0 and OIDC with these identity providers:
- Okta
- Azure AD (Entra ID)
- Ping Identity
- Any SAML 2.0 / OIDC compliant provider

**Setup steps:**
1. Contact Anthropic sales for Enterprise plan activation
2. Provide your IdP metadata URL or XML
3. Configure attribute mapping (email, name, group membership)
4. Test with a pilot group before org-wide rollout
5. Set a default role for new users (standard vs. premium seat)

---

## Managed Policies

Enterprise admins can enforce organisation-wide rules that individual users cannot override:

| Policy | What It Controls |
|:-------|:----------------|
| **Tool permissions** | Which tools Claude can use (Bash, Write, etc.) |
| **File access** | Directories Claude can read/write |
| **MCP servers** | Approved MCP servers; block unapproved ones |
| **Model access** | Which models developers can use (restrict Opus to reduce costs) |
| **Network access** | Whether Claude can make outbound requests |

### Example: Restrictive Policy

```json
{
  "managed_policies": {
    "allowed_tools": ["Read", "Write", "Edit", "Grep", "Glob", "Bash"],
    "blocked_tools": ["WebFetch", "WebSearch"],
    "allowed_mcp_servers": ["context7", "playwright"],
    "max_model": "sonnet",
    "file_restrictions": {
      "blocked_paths": [".env*", "*.pem", "*.key", "secrets/"]
    }
  }
}
```

---

## Compliance API

The Compliance API provides programmatic access to all Claude Code usage data across your organisation.

**What it exposes:**
- Every prompt sent to Claude (full conversation logs)
- Every tool invocation and result
- Files read and modified
- Models used, tokens consumed
- Session duration and timestamps

**Use cases:**
- Feed into your SIEM for security monitoring
- Automated policy enforcement (flag/block certain patterns)
- Selective deletion for data retention compliance
- Audit reports for SOC 2, ISO 27001, HIPAA reviews

### Integration Pattern

```
Claude Code Sessions → Compliance API → Your SIEM/Audit Pipeline
                                      → Data retention enforcement
                                      → Policy violation alerts
```

---

## Spend Controls

| Level | Control | How to Set |
|:------|:--------|:-----------|
| Individual | Personal spending cap | User sets in Claude account settings |
| Per-user (admin) | Maximum spend per user per month | Admin dashboard → User management |
| Organisation | Total org spending cap | Admin dashboard → Billing |
| Per-model | Restrict access to cheaper models | Managed policies |

**Budget formula:**
```
Monthly budget = developers × avg_sessions/day × 20 workdays × avg_cost/session
```

Example: 10 developers × 8 sessions/day × 20 days × $0.50/session = **$800/month** in API costs, plus subscription fees.

---

## Audit Trail Best Practices

### What to Log

| Category | Data Points | Retention |
|:---------|:-----------|:----------|
| **Sessions** | Start/end time, user, project, model used | 90 days minimum |
| **Code changes** | Files modified, diffs generated, commits made | Match your git retention |
| **Tool usage** | Bash commands executed, web requests made | 90 days minimum |
| **Costs** | Tokens consumed per session, per user, per project | 12 months |
| **Policy violations** | Blocked actions, override attempts | 12 months |

### Integration with Existing Compliance

Claude Code audit data should feed into the same pipeline as your other development tools:

```
Git commits → Audit pipeline
PR reviews  → Audit pipeline
Claude Code → Audit pipeline (via Compliance API)
CI/CD logs  → Audit pipeline
```

---

## Shadow AI Prevention

90%+ of organisations have developers using unapproved AI tools via personal accounts. Prevention strategy:

1. **Approve quickly** — The #1 cause of shadow AI is slow procurement. Get an official subscription set up within days, not months.
2. **Make it frictionless** — SSO, pre-configured CLAUDE.md templates, one-line installer. If the official path is harder than personal ChatGPT, developers will use ChatGPT.
3. **Communicate the policy** — "You can use Claude Code with your work account. You must not paste proprietary code into personal AI accounts."
4. **Monitor, don't block** — Network-level blocking of AI tools causes workarounds. Use the Compliance API to monitor usage instead.
5. **Provide training** — This playbook. Developers who know how to use the official tool effectively don't need workarounds.

---

## EU AI Act Preparation

The EU AI Act enters broad enforcement **August 2, 2026**. If your organisation operates in the EU or processes EU citizen data:

| Requirement | Action |
|:-----------|:-------|
| **AI system inventory** | Document all AI coding tools in use (Claude Code, Copilot, etc.) |
| **Risk classification** | AI coding assistants are generally "limited risk" — transparency obligations apply |
| **Transparency** | Developers must know when AI generates code. Claude Code makes this visible by design. |
| **Human oversight** | Code review processes satisfy oversight requirements. Document your review workflow. |
| **Record-keeping** | Compliance API audit logs satisfy record-keeping requirements |
| **AI-BOM (Bill of Materials)** | Document which AI models/versions are used in your development process |

**Fines:** Up to EUR 35M or 7% of global annual turnover — take this seriously.

---

## Rollout Checklist

### Phase 1: Pilot (1-2 weeks)
- [ ] Select 2-3 developers for pilot
- [ ] Set up subscriptions (Max or Team plan)
- [ ] Install playbook with `curl -sL ... | bash`
- [ ] Customize CLAUDE.md template for your stack
- [ ] Run the 2-hour onboarding package

### Phase 2: Expand (2-4 weeks)
- [ ] Gather pilot feedback, update CLAUDE.md
- [ ] Add remaining team members
- [ ] Configure hooks for your build system
- [ ] Set up CI integration (GitHub Actions)
- [ ] Establish spending budgets

### Phase 3: Standardise (ongoing)
- [ ] Move to Enterprise plan if needed (SSO, compliance)
- [ ] Configure managed policies
- [ ] Set up Compliance API integration
- [ ] Add Claude Code to your AI governance documentation
- [ ] Train team leads to customise skills for their projects

### Phase 4: Measure
- [ ] Track deployment frequency before/after
- [ ] Track bug fix time before/after
- [ ] Track code review turnaround before/after
- [ ] Report ROI to leadership quarterly
