---
name: tab-digest
description: "Capture open browser tabs (Chrome session recovery + paywall extraction) and produce a structured research digest with inventory, summaries, and recommendations. Also digests saved emails full of links (inbox mode). Triggers on: 'tab digest', 'digest my tabs', 'research digest', 'process my open tabs', 'digest my emails', 'email digest', 'inbox digest', '/tab-digest', '/tab-digest inbox'. Do NOT use for single-URL summarisation, bookmark management, or non-research browsing sessions."
metadata:
  user-invocable: true
  slash-command: /tab-digest
  proactive: false
---

# Tab Digest

Turns a Chrome browser session (open or recently closed) into a structured research digest:
`inventory.md` → `digest.md` → `recommendations.md`, then de-slopped via `anti-ai-prose`.

## When to invoke

- User says "tab digest", "digest my tabs", "research digest", or "process my open tabs".
- `/tab-digest` is typed.

Do NOT invoke for single-URL summarisation, bookmark management, or sessions that are not research-oriented.

## Output location

All output goes to `~/.claude/research/tab-digest-<YYYY-MM-DD>/`.

```
tab-digest-<date>/
  inventory.md        # full URL list with source type + status
  articles/           # per-article markdown captures
  digest.md           # synthesised findings across all sources
  recommendations.md  # actionable next steps ranked by priority
```

## Step-by-step pipeline

### Step 1 — Recover the Chrome tab list

Even with windows closed, Chrome session files hold the URLs.

```bash
strings ~/Library/Application\ Support/Google/Chrome/Default/Sessions/* \
  | grep -oE 'https?://[^ ]+' \
  | sort -u \
  > /tmp/tab-raw-urls.txt
```

If the user is on a named profile (e.g. "Profile 1"), substitute `Default` with `Profile\ 1`.

Deduplicate and classify each URL by source type: Medium, TikTok, X/Twitter, YouTube, or Other. Write the classified list to `inventory.md` immediately — this is the checkpoint. If the session files are empty or absent, ask the user to export tabs manually (OneTab, etc.) and paste the list.

### Step 1 (inbox mode) — Pull links from saved emails

Use this instead of Step 1 when the user says "inbox", "emails" or "digest my emails". He drags newsletters from Outlook into `~/PaperclipInbox` as `.eml` files.

```bash
python3 ~/.claude/skills/tab-digest/scripts/eml_links.py > /tmp/tab-inbox-links.tsv
```

Each row is: email subject, clean URL (Outlook safelinks and trackers unwrapped, Medium profile pages and footers dropped), and the email's own blurb. Write them to `inventory.md` grouped by email, keep the blurb, then carry on from Step 2. After the digest is written, move the processed `.eml` files into `~/PaperclipInbox/done/`.

### Step 2 — Extract content per source

**A paywall is a problem to get past, never a result.** Try every route below before logging a link as failed. A digest line that just says "paywalled" is a failure of this skill.

Work through `inventory.md` source-by-source. On any extraction failure: log `STATUS: FAILED — <reason>` next to the URL in `inventory.md`, skip, and continue. Never abort the whole run for a single failed source.

#### Medium (paywalled)

Member-only articles only open in the user's logged-in Chrome. Anonymous fetches, and even cookie fetches, return the preview (about 300 words ending in "…"). Check the word count: under 500 words with a trailing "…" means you have the preview, not the article.

First choice: Claude in Chrome (`mcp__claude-in-chrome__*`). Open the URL in a new tab, `get_page_text`, close the tab. Work through the Medium links one at a time.

Second choice — `yt-dlp` cookie extraction (from the memory file verbatim):

```bash
yt-dlp --cookies-from-browser "chrome:Profile 1" \
  --write-info-json --skip-download \
  -o "/tmp/tab-digest-medium/%(title)s.%(ext)s" \
  "<URL>"
```

Fallback — `curl_cffi` Python impersonation (bypasses Cloudflare TLS fingerprinting; plain `curl` will fail):

```python
from curl_cffi import requests as cffi_requests
resp = cffi_requests.get("<URL>", impersonate="chrome131")
```

Delete any exported cookie jar after use.

#### TikTok

Use the embed endpoint directly:

```
https://www.tiktok.com/embed/v2/<ID>
```

Extract the post ID from the share URL and fetch the embed endpoint. Parse the response HTML for the caption and transcript fields.

#### X / Twitter

Use the syndication endpoint (no auth required):

```
https://cdn.syndication.twimg.com/tweet-result?id=<TWEET_ID>
```

Extract the tweet ID from the URL and fetch. Response is JSON; `text` field holds the content.

#### YouTube

Standard `yt-dlp` with subtitle extraction:

```bash
yt-dlp --write-auto-sub --sub-lang en --skip-download \
  -o "/tmp/tab-digest-yt/%(title)s.%(ext)s" \
  "<URL>"
```

#### Instagram

Use the public embed endpoint (no auth) — captions only:

```
https://www.instagram.com/p/<SHORTCODE>/embed/captioned/
https://www.instagram.com/reel/<SHORTCODE>/embed/captioned/
```

Fetch with curl_cffi (`impersonate="chrome131"`), parse `.Caption` / `.UsernameText` from the HTML. Carousel slide text and video content are NOT retrievable without login — note that in the article file. Many AI-content IG posts are comment-gated funnels whose caption is the whole public payload; capture and verdict them anyway.

NEVER classify a source as "personal / not research" on URL alone — capture first, judge from content. Skipping requires evidence (e.g. capture shows it's a shopping cart), not a guess.

#### Other / Generic

Fetch with the Read tool or WebFetch. If behind a paywall with no extractor, log `STATUS: PAYWALL — no extractor` and skip.

### Step 3 — Write intermediate article files

For each successfully extracted source, write a markdown file under `articles/<slug>.md` with:
- URL
- Source type
- Title
- Extracted text / transcript
- One-line summary (written now, used in Step 4)
- Verdict: **Read**, **Skim** or **Skip**, plus one line on why, judged against what the user actually works on (Claude Code setup, agent orchestration, project-g, Project project-e, ParentCo AI work). Check the claims: if an article names a repo or tool, look it up (stars, last commit, is it real) before calling it worth reading. Listicles that repeat what the user already runs are Skip, and say what he already has that covers it.

### Step 4 — Synthesise `digest.md`

Group findings by theme across all successfully captured articles. Structure:

0. Reading list first: every **Read** verdict, one line each with the reason, then the **Skim** ones. Skips go in a collapsed list at the bottom with a one-line reason each
1. Key themes (2–5, each with supporting sources cited by slug)
2. Notable tools / products / techniques mentioned
3. Contradictions or tensions between sources
4. What was NOT captured (sources that failed extraction, with reason)

Keep prose tight. No hype vocabulary. No parallel triplets.

### Step 5 — Write `recommendations.md`

Prioritised action list drawn from the digest. Each item: what to try, why, estimated effort. Max 10 items. Concrete over general.

### Step 6 — MANDATORY: de-slop pass

Run the `anti-ai-prose` skill on both `digest.md` and `recommendations.md` before presenting anything to the user. Do not skip this step.

```
/anti-ai-prose
```

Apply to digest.md and recommendations.md in sequence. Overwrite in place.

### Step 7 — Report

Present to the user:
- Count of tabs recovered, successfully captured, and failed
- Themes from digest.md (headline only, no full dump)
- Top 3 recommendations
- Path to the output directory

## Graceful failure rules

| Failure | Action |
|---|---|
| Chrome session files missing or empty | Ask user to paste URL list; do not abort |
| Medium paywall — yt-dlp fails | Try curl_cffi fallback; if that fails, log FAILED and skip |
| TikTok embed returns 404 | Log FAILED, skip |
| X syndication endpoint 429 | Wait 5s, retry once; if still failing, log FAILED, skip |
| YouTube no subtitles | Note "no transcript available" in article file; still include in digest if title/description is useful |
| curl_cffi not installed | `pip install curl_cffi`, retry once |

## Dependencies

See `references/capture.md` for installation commands and troubleshooting.

Required: `yt-dlp`, `curl_cffi` (Python), `strings` (macOS built-in).
Optional: `ffmpeg` (YouTube audio fallback).
