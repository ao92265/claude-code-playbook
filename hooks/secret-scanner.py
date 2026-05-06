#!/usr/bin/env python3
"""
PreToolUse hook: regex-scan Edit/Write content for credential patterns.

Wider net than env-guard.sh (which only checks `git add`/`git commit` on the
shell side). This catches secrets the moment Claude tries to write them into
any file. Exit 2 blocks the write so the model retries without the secret.

Exit codes:
  0  no match
  1  low/medium-severity match (warn, do not block)
  2  high/critical-severity match (block)

Emergency disable: SECRET_SCANNER_DISABLED=1.
"""
from __future__ import annotations

import json
import os
import re
import sys

# (name, severity, regex). Severity: critical|high|medium.
PATTERNS: list[tuple[str, str, re.Pattern[str]]] = [
    ("AWS Access Key",         "critical", re.compile(r"\b(AKIA|ASIA)[0-9A-Z]{16}\b")),
    ("AWS Secret Key",         "critical", re.compile(r"(?i)aws(.{0,20})?(secret|access)?[_-]?key.{0,5}['\"][0-9a-zA-Z/+=]{40}['\"]")),
    ("Anthropic API Key",      "critical", re.compile(r"\bsk-ant-[a-zA-Z0-9_-]{20,}\b")),
    ("OpenAI API Key",         "critical", re.compile(r"\bsk-(?!ant-)(?:proj-)?[A-Za-z0-9_-]{20,}\b")),
    ("GitHub PAT (classic)",   "critical", re.compile(r"\bghp_[A-Za-z0-9]{36}\b")),
    ("GitHub PAT (fine)",      "critical", re.compile(r"\bgithub_pat_[A-Za-z0-9_]{82}\b")),
    ("GitHub OAuth",           "critical", re.compile(r"\bgho_[A-Za-z0-9]{36}\b")),
    ("Stripe Live Key",        "critical", re.compile(r"\bsk_live_[A-Za-z0-9]{20,}\b")),
    ("Stripe Restricted Key",  "critical", re.compile(r"\brk_live_[A-Za-z0-9]{20,}\b")),
    ("Stripe Test Key",        "high",     re.compile(r"\bsk_test_[A-Za-z0-9]{20,}\b")),
    ("Google API Key",         "critical", re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b")),
    ("Slack Token",            "critical", re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b")),
    ("Slack Webhook",          "high",     re.compile(r"https://hooks\.slack\.com/services/T[0-9A-Z]+/B[0-9A-Z]+/[0-9A-Za-z]+")),
    ("Discord Webhook",        "medium",   re.compile(r"https://discord(?:app)?\.com/api/webhooks/\d+/[A-Za-z0-9_-]+")),
    ("Supabase Service Role",  "critical", re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{20,}\b")),
    ("Vercel Token",           "high",     re.compile(r"\b[a-zA-Z0-9]{24}\b(?=.*vercel)", re.IGNORECASE)),
    ("HuggingFace Token",      "high",     re.compile(r"\bhf_[A-Za-z0-9]{30,}\b")),
    ("Replicate Token",        "high",     re.compile(r"\br8_[A-Za-z0-9]{30,}\b")),
    ("Groq API Key",           "high",     re.compile(r"\bgsk_[A-Za-z0-9]{40,}\b")),
    ("Databricks Token",       "high",     re.compile(r"\bdapi[a-f0-9]{32,}\b")),
    ("Azure Storage Key",      "critical", re.compile(r"DefaultEndpointsProtocol=https;AccountName=[^;]+;AccountKey=[A-Za-z0-9+/=]{60,}")),
    ("DigitalOcean Token",     "high",     re.compile(r"\bdop_v1_[a-f0-9]{64}\b")),
    ("Linear API Key",         "high",     re.compile(r"\blin_api_[A-Za-z0-9]{40,}\b")),
    ("Notion Integration",     "high",     re.compile(r"\bsecret_[A-Za-z0-9]{43}\b")),
    ("Private Key Block",      "critical", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----")),
    ("Generic JWT",            "medium",   re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b")),
    ("Generic Bearer Token",   "medium",   re.compile(r"(?i)bearer\s+[A-Za-z0-9._-]{20,}")),
    ("Hardcoded Password",     "medium",   re.compile(r"(?i)(?:password|passwd|pwd)\s*[:=]\s*['\"][^'\"\s]{6,}['\"]")),
    ("DB Connection w/ creds", "high",     re.compile(r"(?i)(?:postgres|postgresql|mysql|mongodb(?:\+srv)?)://[^:\s]+:[^@\s]+@")),
    ("Twilio Auth Token",      "high",     re.compile(r"\bSK[a-f0-9]{32}\b")),
]


def main() -> int:
    if os.environ.get("SECRET_SCANNER_DISABLED") == "1":
        return 0

    raw = sys.stdin.read()
    if not raw:
        return 0
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return 0

    tool = payload.get("tool_name", "")
    if tool not in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
        return 0

    inp = payload.get("tool_input", {}) or {}
    file_path = inp.get("file_path", "") or inp.get("notebook_path", "")

    # Allow obvious example/test fixtures.
    lowered = file_path.lower()
    if any(seg in lowered for seg in ("/fixtures/", "/__fixtures__/", "/examples/", "secret-scanner")):
        return 0

    blobs: list[str] = []
    for k in ("content", "new_string", "new_str"):
        v = inp.get(k)
        if isinstance(v, str):
            blobs.append(v)
    edits = inp.get("edits")
    if isinstance(edits, list):
        for e in edits:
            if isinstance(e, dict):
                v = e.get("new_string") or e.get("new_str")
                if isinstance(v, str):
                    blobs.append(v)
    if not blobs:
        return 0

    text = "\n".join(blobs)
    hits: list[tuple[str, str, str]] = []
    for name, sev, rx in PATTERNS:
        m = rx.search(text)
        if m:
            sample = m.group(0)
            if len(sample) > 60:
                sample = sample[:30] + "…" + sample[-10:]
            hits.append((name, sev, sample))

    if not hits:
        return 0

    worst = "medium"
    rank = {"medium": 1, "high": 2, "critical": 3}
    for _, sev, _ in hits:
        if rank[sev] > rank[worst]:
            worst = sev

    print("Secret scanner matches:", file=sys.stderr)
    for name, sev, sample in hits:
        print(f"  [{sev.upper()}] {name}: {sample}", file=sys.stderr)
    print(f"  → file: {file_path or '<unknown>'}", file=sys.stderr)
    print("  Move the value to an env var or .env (gitignored), or use a placeholder.", file=sys.stderr)
    print("  Bypass for one session: export SECRET_SCANNER_DISABLED=1", file=sys.stderr)

    if worst in ("critical", "high"):
        return 2
    return 1


if __name__ == "__main__":
    sys.exit(main())
