# Tab capture — commands and troubleshooting

Reference for the commands used in the tab-digest pipeline. Linked from SKILL.md.

## Installation (one-time)

```bash
# yt-dlp
brew install yt-dlp

# curl_cffi (Python — needed for Cloudflare-protected Medium pages)
pip install curl_cffi

# ffmpeg (optional — YouTube audio fallback)
brew install ffmpeg
```

Check versions:

```bash
yt-dlp --version
python3 -c "import curl_cffi; print(curl_cffi.__version__)"
```

---

## Chrome session recovery

Tabs survive window closes in the Sessions directory:

```bash
strings ~/Library/Application\ Support/Google/Chrome/Default/Sessions/* \
  | grep -oE 'https?://[^ ]+' \
  | sort -u \
  > /tmp/tab-raw-urls.txt
```

Named profile variant (substitute your profile folder name):

```bash
strings ~/Library/Application\ Support/Google/Chrome/Profile\ 1/Sessions/* \
  | grep -oE 'https?://[^ ]+' \
  | sort -u \
  > /tmp/tab-raw-urls.txt
```

Find your profile folders:

```bash
ls ~/Library/Application\ Support/Google/Chrome/ | grep -E '^(Default|Profile)'
```

**Gotchas:**
- Sessions files are binary; `strings` extracts readable text fragments. Some URLs will be partial — discard anything without a valid TLD.
- Files rotate. If the session is more than a day old the URLs may be gone. Fallback: Chrome's History database (`History` SQLite file in the same profile folder).
- Chrome must not be actively writing the Sessions file. Quit Chrome first or copy the file before running `strings`.

---

## Medium — yt-dlp cookie extraction

Extracts cookies from the live Chrome profile to authenticate the request:

```bash
yt-dlp --cookies-from-browser "chrome:Profile 1" \
  --write-info-json --skip-download \
  -o "/tmp/tab-digest-medium/%(title)s.%(ext)s" \
  "<URL>"
```

- Replace `Profile 1` with your actual Chrome profile name (find it with the `ls` command above).
- `--write-info-json` saves metadata including description/body text into a `.info.json` file.
- `--skip-download` avoids downloading any media; we only want the text.
- Delete the cookie jar after use: `rm /tmp/cookies.txt` if yt-dlp wrote one explicitly.

**Gotchas:**
- Requires Chrome to be closed (or the profile not actively locked) for cookie access on macOS.
- yt-dlp version must be recent (2024+). Update with `brew upgrade yt-dlp`.
- Member-only articles require the cookie to be from an account with an active Medium membership.

---

## Medium — curl_cffi fallback

Plain `curl` fails Cloudflare's TLS fingerprinting on Medium. `curl_cffi` impersonates a real browser:

```python
from curl_cffi import requests as cffi_requests

resp = cffi_requests.get("<URL>", impersonate="chrome131")
html = resp.text
```

Parse the article body from the HTML. Medium embeds article JSON in a `<script type="application/json">` tag — parse that first; fall back to `<article>` tag text extraction.

**Gotchas:**
- `chrome131` is the impersonation target used in the working pipeline. If it stops working, try `chrome120` or `chrome110`.
- Does not bypass the Member paywall, only Cloudflare bot detection. Still needs a valid session cookie for member-only content.

---

## TikTok — embed endpoint

No auth required for public posts:

```
https://www.tiktok.com/embed/v2/<POST_ID>
```

Extract the post ID from share URLs:
- `https://www.tiktok.com/@user/video/7123456789` → ID is `7123456789`
- Short URLs (`vm.tiktok.com/...`) redirect — follow the redirect first to get the canonical URL.

```bash
curl -sL "https://vm.tiktok.com/SHORTCODE/" | grep -oE 'video/[0-9]+' | head -1
```

**Gotchas:**
- The embed endpoint returns HTML, not JSON. Scrape the `<p>` tag with class `video-meta-title` for caption.
- Carousel posts (multiple images) may return limited text. Note in inventory.

---

## X / Twitter — syndication endpoint

No auth, no API key:

```
https://cdn.syndication.twimg.com/tweet-result?id=<TWEET_ID>
```

Extract tweet ID from URL:
- `https://x.com/user/status/1234567890` → ID is `1234567890`
- `https://twitter.com/user/status/1234567890` → same pattern

Response is JSON. Fields of interest: `text`, `user.name`, `created_at`, `entities.urls`.

**Gotchas:**
- Rate limit is undocumented. Space requests 1–2 seconds apart on large batches.
- Deleted or suspended account tweets return 404 — log and skip.
- Threads: only the linked tweet is returned; replies are separate requests.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `strings` returns no URLs | Sessions files empty or wrong profile | Try other profile folders; check Chrome was opened recently |
| yt-dlp: `Unsupported URL` on Medium | yt-dlp doesn't handle Medium natively | Use `--write-info-json` or switch to curl_cffi fallback |
| curl_cffi: `ModuleNotFoundError` | Not installed | `pip install curl_cffi` |
| Medium body is empty in .info.json | Article is member-only + cookie not authenticated | Ensure Chrome profile is logged in to Medium with membership |
| TikTok embed returns 403 | Post is private or region-restricted | Log FAILED, skip |
| X syndication returns 404 | Tweet deleted, account suspended, or ID wrong | Log FAILED, skip |
| Chrome profile locked error from yt-dlp | Chrome is running with that profile open | Quit Chrome, retry; or copy the Cookies file manually |
