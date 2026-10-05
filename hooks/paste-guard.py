#!/usr/bin/env python3
"""
UserPromptSubmit hook: paste-guard — DLP gate for what YOU paste into Claude Code.

Companion to secret-scanner.py (which scans what Claude WRITES to files).
This one scans what the USER SUBMITS: if the prompt contains credentials,
PII, or a pasted image, it blocks the prompt and puts a sanitized copy of
the text on the clipboard so you can re-paste clean in two keystrokes.

Proof of concept for Project project-h.

On detection:
  - prompt is blocked + erased (decision:"block", suppressOriginalPrompt)
  - sanitized text (matches -> [REDACTED:<type>], image markers stripped)
    replaces the clipboard via pbcopy — Cmd+V to resend clean
  - the block message lists WHAT was caught (names + counts, never values)
  - a counts-only event is appended to ~/.claude/logs/paste-guard.jsonl

Sanitize mode (project-h clipboard layer):
  paste-guard.py --sanitize   reads PLAIN TEXT on stdin, writes sanitized
  text to stdout. Exit 1 if anything was redacted, 0 if clean. Errors fail
  open (original text, exit 0). Image markers are ignored in this mode —
  clipboard text never contains them. Used by ~/.hammerspoon/init.lua.

Escape hatches:
  - start the message with !!raw       -> this one prompt passes untouched
    (also honoured in --sanitize mode: clipboard starting !!raw passes)
  - /paste-guard off                   -> off until /paste-guard on
    (writes ~/.claude/state/paste-guard/off; covers the desktop layer too)
  - export PASTE_GUARD_DISABLED=1      -> off, but ONLY if exported in the
    shell BEFORE `claude` starts. An export typed inside a session cannot
    reach this hook.
  - export PASTE_GUARD_BLOCK_IMAGES=1  -> strict mode: block pasted images
    (default is images PASS — flipped 2026-07-13, screenshots are daily flow)
Debug: PASTE_GUARD_DEBUG=1 adds a redacted 200-char preview to the log
(use once to verify whether image pastes are visible to the hook at all).
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time

# --- config ---------------------------------------------------------------
BLOCK_IMAGES = False   # opt-in via PASTE_GUARD_BLOCK_IMAGES=1 — default-on broke daily screenshot pastes
REDACT_EMAILS = True   # flip to False if email blocking gets annoying day-to-day
BYPASS_PREFIX = "!!raw"
LOG_PATH = os.path.expanduser("~/.claude/logs/paste-guard.jsonl")
# Off-switch state file. Presence = guard off for EVERY layer (prompt hook,
# clipboard sanitizer, image OCR). A file, not an env var: an `export` typed
# inside a Claude session dies with its subshell and never reaches this hook,
# so the env switch below can only ever be set before `claude` launches.
STATE_OFF = os.path.expanduser("~/.claude/state/paste-guard/off")
# Emails at these domains (and their subdomains) are NOT redacted — own work
# addresses were 52 of the first 111 blocks, all noise. Add a domain here.
EMAIL_ALLOW_DOMAINS = ("example-corp.com", "acmeco.co.uk")

# (label, regex) — every match blocks. Credential set mirrors secret-scanner.py
# (critical/high tiers) so the two hooks stay conceptually in sync.
PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    ("AWS Access Key",        re.compile(r"\b(AKIA|ASIA)[0-9A-Z]{16}\b")),
    ("AWS Secret Key",        re.compile(r"(?i)aws(.{0,20})?(secret|access)?[_-]?key.{0,5}['\"][0-9a-zA-Z/+=]{40}['\"]")),
    ("Anthropic API Key",     re.compile(r"\bsk-ant-[a-zA-Z0-9_-]{20,}\b")),
    ("OpenAI API Key",        re.compile(r"\bsk-(?!ant-)(?:proj-)?[A-Za-z0-9_-]{20,}\b")),
    ("GitHub Token",          re.compile(r"\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36}\b|\bgithub_pat_[A-Za-z0-9_]{82}\b")),
    ("Stripe Key",            re.compile(r"\b[sr]k_(?:live|test)_[A-Za-z0-9]{20,}\b")),
    ("Google API Key",        re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b")),
    ("Slack Token",           re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b")),
    ("Slack Webhook",         re.compile(r"https://hooks\.slack\.com/services/T[0-9A-Z]+/B[0-9A-Z]+/[0-9A-Za-z]+")),
    ("HuggingFace Token",     re.compile(r"\bhf_[A-Za-z0-9]{30,}\b")),
    ("Groq API Key",          re.compile(r"\bgsk_[A-Za-z0-9]{40,}\b")),
    ("Databricks Token",      re.compile(r"\bdapi[a-f0-9]{32,}\b")),
    ("Azure Storage Key",     re.compile(r"DefaultEndpointsProtocol=https;AccountName=[^;]+;AccountKey=[A-Za-z0-9+/=]{60,}")),
    ("DigitalOcean Token",    re.compile(r"\bdop_v1_[a-f0-9]{64}\b")),
    ("Private Key Block",     re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----[\s\S]*?-----END (?:RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----")),
    # truncated paste: no END marker — redact from BEGIN to end of text so no
    # key material survives into the sanitized copy
    ("Private Key Block",     re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----[\s\S]*\Z")),
    ("JWT",                   re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b")),
    ("Bearer Token",          re.compile(r"(?i)\bbearer\s+[A-Za-z0-9._-]{20,}")),
    ("Hardcoded Password",    re.compile(r"(?i)(?:(?:password|passwd|pwd)\s*[:=]\s*['\"][^'\"\s]{6,}['\"]|\b(?:password|passwd|pwd)\s*=\s*[^\s'\"]{6,})")),
    ("Env-style Secret",      re.compile(r"(?im)(?:^|[\s;])(?:export\s+)?[A-Z0-9_]*(?:SECRET|TOKEN|PASSWORD|PASSWD|API_?KEY|ACCESS_KEY|PRIVATE_KEY|CREDENTIALS?)[A-Z0-9_]*\s*=\s*['\"]?\S{8,}")),
    ("DB Connection Creds",   re.compile(r"(?i)(?:postgres|postgresql|mysql|mongodb(?:\+srv)?|redis|amqp)://[^:\s/]+:[^@\s]+@")),
    ("Basic-Auth URL",        re.compile(r"\bhttps?://[^:\s/]+:[^@\s]+@")),
    ("UK National Insurance", re.compile(r"\b[A-CEGHJ-PR-TW-Z][A-CEGHJ-NPR-TW-Z]\s?\d{2}\s?\d{2}\s?\d{2}\s?[A-D]\b")),
]

EMAIL = ("Email", re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"))

# How pasted images appear in Claude Code prompt text (observed in transcripts).
IMAGE_MARKER = re.compile(r"\[Image #\d+\]|\[Image: source: [^\]]*\]")

# File-backed attachments (dragged files / file-reference pastes) expose their
# path — those we can OCR-scan via the project-h pipeline.
# ⚠️ LIVE-VERIFIED 2026-07-16: the hook's `prompt` field contains ONLY
# "[Image #N]" placeholders — Claude Code appends "[Image: source: path]"
# markers AFTER the hook stage, so this path never fires interactively today.
# Kept as defence-in-depth (headless/-p flows, future CC versions). Real
# file-route coverage = Hammerspoon pathwatchers on image-cache +
# TemporaryItems (init.lua M1.6), censoring files in place on disk.
IMAGE_SOURCE = re.compile(r"\[Image: source: ([^\]]+)\]")
PG_IMG_SH = os.path.expanduser("~/.hammerspoon/paste-guard/paste-guard-img.sh")
PG_WORK = os.path.expanduser("~/.hammerspoon/paste-guard/.work")
IMAGE_EXTS = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".tiff", ".heic")
MAX_IMAGE_BYTES = 20_000_000
MAX_IMAGES_SCANNED = 5


def scan_image_sources(prompt: str) -> tuple[int, str | None]:
    """OCR-scan file-backed image attachments through project-h-img.sh.
    Returns (dirty_count, path_of_first_censored_png_or_None). Fail-open:
    any error or missing tooling counts the image as clean."""
    if not os.path.isfile(PG_IMG_SH):
        return 0, None
    dirty = 0
    censored: str | None = None
    for i, path in enumerate(IMAGE_SOURCE.findall(prompt)[:MAX_IMAGES_SCANNED]):
        path = path.strip()
        try:
            if not (path.lower().endswith(IMAGE_EXTS) and os.path.isfile(path)
                    and os.path.getsize(path) <= MAX_IMAGE_BYTES):
                continue
            out = os.path.join(PG_WORK, f"hook-censored-{os.getpid()}-{i}.png")
            r = subprocess.run(["/bin/bash", PG_IMG_SH, path, out],
                               capture_output=True, timeout=15)
            if r.returncode == 1:
                dirty += 1
                if censored is None:
                    censored = out
                else:
                    os.remove(out)
        except Exception:
            continue
    return dirty, censored


CACHE_ROOT = os.path.expanduser("~/.claude/image-cache")
CACHE_RECENT_SECONDS = 600
BARE_IMAGE_MARKER = re.compile(r"\[Image #\d+\]")


def scan_image_cache(session_id: str | None, prompt: str) -> tuple[int, str | None]:
    """OCR-scan this session's recently-written image-cache files at SUBMIT
    time and censor dirty ones in place. This is the only timing-safe image
    gate: Hammerspoon watchers censor the cache on disk but RACE Claude
    Code's read (live-proven 2026-07-16: cache copy censored at 18:55:41,
    original bytes still reached the API). A hook block stops the send
    entirely. Returns (dirty_count, censored_path_or_None) — the censored
    path is the CACHE file itself (do not delete it)."""
    if not session_id or not BARE_IMAGE_MARKER.search(prompt):
        return 0, None
    d = os.path.join(CACHE_ROOT, str(session_id))
    if not os.path.isdir(d) or not os.path.isfile(PG_IMG_SH):
        return 0, None
    now = time.time()
    dirty = 0
    keep: str | None = None
    try:
        pngs = [os.path.join(d, f) for f in os.listdir(d)
                if f.lower().endswith(".png")]
        pngs.sort(key=lambda p: os.path.getmtime(p), reverse=True)
    except OSError:
        return 0, None
    for i, path in enumerate(pngs[:MAX_IMAGES_SCANNED]):
        try:
            if now - os.path.getmtime(path) > CACHE_RECENT_SECONDS:
                continue
            if os.path.getsize(path) > MAX_IMAGE_BYTES:
                continue
            out = os.path.join(PG_WORK, f"hook-cache-{os.getpid()}-{i}.png")
            r = subprocess.run(["/bin/bash", PG_IMG_SH, path, out],
                               capture_output=True, timeout=15)
            if r.returncode == 1:
                dirty += 1
                os.replace(out, path)  # censor the cache copy for any re-read
                if keep is None:
                    keep = path
        except Exception:
            continue
    return dirty, keep


def copy_image_to_clipboard(png_path: str) -> bool:
    """Put a PNG on the macOS clipboard (replaces any text put there)."""
    try:
        script = f'set the clipboard to (read (POSIX file "{png_path}") as «class PNGf»)'
        subprocess.run(["osascript", "-e", script], capture_output=True,
                       timeout=5, check=True)
        return True
    except Exception:
        return False

CARD_CANDIDATE = re.compile(r"\b\d(?:[ -]?\d){12,18}\b")


def luhn_ok(digits: str) -> bool:
    total = 0
    for i, ch in enumerate(reversed(digits)):
        d = int(ch)
        if i % 2 == 1:
            d *= 2
            if d > 9:
                d -= 9
        total += d
    return total % 10 == 0


def redact_cards(text: str) -> tuple[str, int]:
    count = 0

    def sub(m: re.Match[str]) -> str:
        nonlocal count
        digits = re.sub(r"\D", "", m.group(0))
        if 13 <= len(digits) <= 19 and luhn_ok(digits):
            count += 1
            return "[REDACTED:Payment Card]"
        return m.group(0)

    return CARD_CANDIDATE.sub(sub, text), count


def guard_off() -> bool:
    """True when the guard is switched off, by state file or by env var."""
    if os.environ.get("PASTE_GUARD_DISABLED") == "1":
        return True
    try:
        return os.path.exists(STATE_OFF)
    except OSError:
        return False


def domain_allowed(addr: str) -> bool:
    """True if addr's domain is an allowlisted domain or a subdomain of one."""
    domain = addr.rsplit("@", 1)[-1].lower().rstrip(".")
    return any(domain == d or domain.endswith("." + d) for d in EMAIL_ALLOW_DOMAINS)


def redact_emails(text: str) -> tuple[str, int]:
    """Redact every email EXCEPT allowlisted domains. Returns (text, count)."""
    count = 0

    def sub(m: "re.Match[str]") -> str:
        nonlocal count
        if domain_allowed(m.group(0)):
            return m.group(0)
        count += 1
        return "[REDACTED:Email]"

    return EMAIL[1].sub(sub, text), count


def log_event(event: dict) -> None:
    try:
        os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)
        with open(LOG_PATH, "a") as f:
            f.write(json.dumps(event) + "\n")
    except OSError:
        pass


MAX_SCAN_CHARS = 8_000_000  # fail-open above this rather than risk a stall


# Wrapped-secret sweep: terminals hard-wrap long tokens, so only the first
# chunk matches a credential pattern — the continuation lines are bare
# base64url with no prefix to key on. After any NON-email redaction (fresh,
# or a literal [REDACTED:…] already present — i.e. a re-paste of previously
# sanitized text), consume following lines that are pure token material.
# Real incident 2026-07-16: OAuth token tail fragments reached two
# transcripts this way.
REDACTION_ANCHOR = re.compile(r"\[REDACTED:(?!Email\])[^\]]+\]")
# URL-safe charset only (sk-ant/JWT/gh tokens): keeps paths (/) and normal
# prose (spaces) out of the blast radius.
TOKEN_FRAGMENT_LINE = re.compile(r"^[ \t]*[A-Za-z0-9_-]{12,}[ \t]*$")


def sweep_wrapped_fragments(text: str) -> tuple[str, int]:
    lines = text.split("\n")
    count = 0
    armed = False
    for i, ln in enumerate(lines):
        if REDACTION_ANCHOR.search(ln):
            armed = True
        elif armed and TOKEN_FRAGMENT_LINE.match(ln):
            lines[i] = "[REDACTED:Token Fragment]"
            count += 1
        else:
            armed = False  # any other line (incl. blank) ends the wrap run
    return "\n".join(lines), count


def sanitize_text(text: str) -> tuple[str, dict[str, int]]:
    """Redact every pattern match. Returns (sanitized, {label: count})."""
    findings: dict[str, int] = {}
    sanitized = text

    for label, rx in PATTERNS:
        sanitized, n = rx.subn(f"[REDACTED:{label}]", sanitized)
        if n:
            findings[label] = findings.get(label, 0) + n

    if REDACT_EMAILS:
        sanitized, n_mail = redact_emails(sanitized)
        if n_mail:
            findings["Email"] = findings.get("Email", 0) + n_mail

    sanitized, n_cards = redact_cards(sanitized)
    if n_cards:
        findings["Payment Card"] = n_cards

    sanitized, n_frag = sweep_wrapped_fragments(sanitized)
    if n_frag:
        findings["Token Fragment"] = n_frag
    return sanitized, findings


def sanitize_mode() -> int:
    """--sanitize: plain text stdin -> sanitized stdout. Exit 1 = redacted."""
    text = sys.stdin.read()
    if not text:
        return 0
    if (guard_off()
            or text.lstrip().startswith(BYPASS_PREFIX)
            or len(text) > MAX_SCAN_CHARS):
        sys.stdout.write(text)
        return 0

    try:
        sanitized, findings = sanitize_text(text)
    except Exception:
        sys.stdout.write(text)
        return 0

    sys.stdout.write(sanitized)
    if findings:
        log_event({"ts": time.strftime("%Y-%m-%dT%H:%M:%S"),
                   "source": "clipboard", "redacted": True,
                   "findings": findings, "text_chars": len(text)})
        return 1
    return 0


def scan_lines_mode() -> int:
    """--scan-lines: one text per stdin line -> stdout 1-based indices of
    lines containing sensitive matches (space-separated). Used by the project-h
    image censor to decide which OCR boxes to black out. Always exits 0.
    Limitation: multi-line secrets (private key bodies) only flag the BEGIN
    line — the truncated-key pattern catches it; following base64 lines pass.
    """
    if guard_off():
        return 0
    dirty: list[str] = []
    for i, line in enumerate(sys.stdin, 1):
        try:
            _, findings = sanitize_text(line.rstrip("\n"))
        except Exception:
            continue
        if findings:
            dirty.append(str(i))
    if dirty:
        sys.stdout.write(" ".join(dirty) + "\n")
        log_event({"ts": time.strftime("%Y-%m-%dT%H:%M:%S"),
                   "source": "image-ocr", "redacted": True,
                   "dirty_lines": len(dirty)})
    return 0


def main() -> int:
    if guard_off():
        return 0

    raw = sys.stdin.read()
    if not raw:
        return 0
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return 0
    if not isinstance(payload, dict):
        return 0
    if payload.get("hook_event_name") not in (None, "UserPromptSubmit"):
        return 0

    prompt = payload.get("prompt", "")
    if not isinstance(prompt, str) or not prompt:
        return 0
    if prompt.lstrip().startswith(BYPASS_PREFIX):
        return 0
    if len(prompt) > MAX_SCAN_CHARS:
        log_event({"ts": time.strftime("%Y-%m-%dT%H:%M:%S"),
                   "skipped": "oversize", "prompt_chars": len(prompt)})
        return 0

    sanitized, findings = sanitize_text(prompt)

    img_count = 0
    censored_img = None
    if BLOCK_IMAGES or os.environ.get("PASTE_GUARD_BLOCK_IMAGES") == "1":
        sanitized, img_count = IMAGE_MARKER.subn("", sanitized)
        if img_count:
            findings["Pasted Image"] = img_count
    else:
        # Default mode: images pass UNLESS OCR finds secrets. Two scans:
        # file-backed source markers (dead interactively, kept as backstop)
        # and the session image-cache (the timing-safe gate — see docstring).
        n_src, censored_img = scan_image_sources(prompt)
        n_cache, censored_cache = scan_image_cache(payload.get("session_id"), prompt)
        if censored_img is None:
            censored_img = censored_cache
        if n_src + n_cache:
            findings["Screenshot with secrets"] = n_src + n_cache

    event = {
        "ts": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "blocked": bool(findings),
        "findings": findings,
        "prompt_chars": len(prompt),
    }
    if os.environ.get("PASTE_GUARD_DEBUG") == "1":
        event["redacted_preview"] = sanitized[:200]
    log_event(event)

    def discard_censored_temp() -> None:
        # Only PG_WORK temps are ours to delete — a censored image-cache
        # file must stay in place (it IS the sanitized attachment).
        if censored_img and censored_img.startswith(PG_WORK):
            try:
                os.remove(censored_img)
            except OSError:
                pass

    if not findings:
        discard_censored_temp()
        return 0

    caught = ", ".join(f"{k} ×{v}" for k, v in findings.items())
    lines = [f"🛡️ paste-guard blocked this prompt — caught: {caught}."]

    image_only = censored_img is not None and set(findings) == {"Screenshot with secrets"}
    if image_only:
        # Only the screenshot is dirty: put the CENSORED IMAGE on the clipboard.
        if copy_image_to_clipboard(censored_img):
            lines.append("A censored copy of the screenshot is on your clipboard — paste it again (Ctrl+V) and resend.")
        else:
            lines.append("Couldn't put the censored copy on the clipboard — retake the screenshot without the sensitive lines.")
    else:
        clip_ok = True
        try:
            subprocess.run(["pbcopy"], input=sanitized.encode(),
                           timeout=3, check=True)
        except Exception:
            clip_ok = False
        if clip_ok:
            lines.append("A sanitized copy is on your clipboard — Cmd+V and send again.")
        else:
            lines.append("Clipboard copy failed — remove the flagged items manually and resend.")
        if censored_img:
            lines.append("A screenshot in this prompt ALSO contains secrets — retake it before resending (text copy took clipboard priority).")
    discard_censored_temp()
    if img_count:
        lines.append("Pasted image stripped: the re-paste is text-only (the image attachment is not included).")
    lines.append("Bypass once: start the message with !!raw · turn the guard off: /paste-guard off")

    out = {
        "decision": "block",
        "reason": "\n".join(lines),
        "suppressOriginalPrompt": True,
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "suppressOriginalPrompt": True,
        },
    }
    print(json.dumps(out))
    return 0


if __name__ == "__main__":
    # Any unexpected error must fail open — never break prompt submission.
    try:
        if "--sanitize" in sys.argv[1:]:
            sys.exit(sanitize_mode())
        if "--scan-lines" in sys.argv[1:]:
            sys.exit(scan_lines_mode())
        sys.exit(main())
    except Exception:
        sys.exit(0)
