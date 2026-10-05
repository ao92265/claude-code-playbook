---
name: demo-qa
description: >
  Browser-driven demo-readiness QA. Starts the app fresh, drives the
  demo-critical flows via the Chrome MCP, hard-refreshes to kill stale tabs,
  screenshots and asserts each flow against the rendered DOM, and when something
  is wrong finds the ROOT CAUSE in source (not a screenshot patch), fixes,
  restarts, and re-runs. Ends by presenting evidence and asking YOU to confirm in
  your real browser — it never self-certifies the UI. Use before a demo.
  Triggers: "/demo-qa", "demo readiness", "is the demo ready", "harden the demo",
  "QA the routes/pages", "check every page", "go through these complaints" (numbered
  UI-complaint or video-complaint lists), "sweep the UI", route-by-route browser QA.

  Do NOT use for: static screenshot-vs-reference comparison (use visual-verdict),
  or backend-only verification (use /done or /review).
metadata:
  user-invocable: true
  slash-command: /demo-qa
  proactive: false
effort: high
---

# Demo-QA — Browser-Verified, Human-Gated

Demo prep eats whole sessions: rebuilding eform PDFs, fixing chatbot markdown
across screenshots, chasing stale browser tabs. This skill automates the loop —
but stops short of certifying. CLAUDE.md is explicit: **never certify a UI fix
from your own screenshots; find the root cause in source, then ask the user to
confirm in their real browser.** This skill obeys that rule by design.

## Protocol

1. **Fresh start.** Kill stale dev-server instances, start the server fresh,
   confirm it is serving before driving the browser.

2. **Enumerate demo-critical flows.** Ask the user for the flow list if not
   given, else infer from the task. Examples seen before: PDF ingest, filled
   NCF/SOH rendering, chatbot markdown formatting, thumbs up/down, the AI badge.

3. **Drive each flow** via the Chrome MCP (`mcp__claude-in-chrome__*`):
   - `tabs_context_mcp` first; create a new tab — never reuse a stale one.
   - **Hard-refresh** before each flow to avoid stale-tab artifacts.
   - Screenshot, then assert the rendered DOM matches expected state
     (`read_page` / `get_page_text`, or the chrome-devtools `evaluate_script`).
     Don't trust the screenshot alone for pass/fail — assert the DOM.
   - Avoid actions that trigger native dialogs (alert/confirm/prompt) — they
     freeze the extension.

4. **On failure: root-cause in source.** When a flow renders wrong, find the
   cause in the code — orphaned component, stale import, wrong data shape — fix
   it, restart the server, re-run that flow. Do NOT patch the screenshot or
   tweak CSS blindly to make one screenshot look right.

5. **Stop and hand off — do NOT certify.** When the flows pass your DOM
   assertions, STOP. Present: per-flow status, the screenshots, root causes
   fixed. Then ask the user to confirm in their real browser. The verdict is
   "ready for your review", never "demo-ready / shipped". The demo is ready only
   after the user confirms.

## Hard Rules

- Never output a "demo-ready / certified" verdict from your own screenshots.
  The final word is the user's, in their real browser. (CLAUDE.md,
  non-negotiable.)
- Find root cause in source before any fix; no screenshot-patching.
- 2–3 failed browser actions or no extension response → stop and ask the user;
  don't loop.
- Record a GIF (`gif_creator`) of the run when it would help the user review.

## Why This Skill Exists

`/insights` (2026-06-29): demo-prep / browser QA repeatedly consumed sessions,
with stale tabs and screenshot-chasing as recurring friction. This automates the
drive-assert-fix loop while preserving the user's hard rule that only they
certify UI in a real browser.
