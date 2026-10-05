#!/usr/bin/env python3
"""List the content links in saved emails, with the email's own blurb for each.
Usage: eml_links.py [folder]   (default ~/PaperclipInbox; reads *.eml, skips done/)
Prints TSV: email subject, url, anchor text / nearby blurb."""
import sys, os, re, glob, html, email
from email import policy
from urllib.parse import urlparse, parse_qs, urlunparse

folder = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/PaperclipInbox")
JUNK = re.compile(r"unsubscribe|/settings|/me/|/policy|/privacy|/terms|help\.medium|/m/signin|/plans|"
                  r"mailto:|/jobs-at|/about|list-manage|/tag/|/followers|/membership|/app-store|play\.google|"
                  r"apps\.apple|itunes\.apple|google\.com/maps|facebook\.com/sharer|twitter\.com/intent|\.(png|jpg|gif)(\?|$)", re.I)

def clean(u):
    u = html.unescape(u)
    p = urlparse(u)
    q = parse_qs(p.query)
    for k in ("url", "u", "q", "redirect", "target"):  # unwrap redirectors
        if k in q and q[k][0].startswith("http"):
            return clean(q[k][0])
    if "medium.com" in p.netloc or p.netloc.endswith(".medium.com"):
        p = p._replace(query="", fragment="")  # drop tracking
    return urlunparse(p)

for path in sorted(glob.glob(os.path.join(folder, "*.eml"))):
    msg = email.message_from_bytes(open(path, "rb").read(), policy=policy.default)
    subj = str(msg["subject"] or os.path.basename(path)).replace("\t", " ")
    body = msg.get_body(preferencelist=("html", "plain"))
    text = body.get_content() if body else ""
    seen = set()
    for m in re.finditer(r'<a\s[^>]*href="([^"]+)"[^>]*>(.*?)</a>', text, re.S | re.I):
        url, anchor = clean(m.group(1)), re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", m.group(2)))).strip()
        if not url.startswith("http") or JUNK.search(url) or url in seen:
            continue
        up = urlparse(url)
        segs = [x for x in up.path.split("/") if x]
        if up.netloc.endswith("medium.com") and len(segs) < (2 if up.netloc in ("medium.com", "www.medium.com") else 1):
            continue  # author, publication or home page, not an article
        seen.add(url)
        # blurb: text right after the link, up to 200 chars
        chunk = re.sub(r"<[^>]*$", "", re.sub(r"<(style|script)[^>]*>.*?</\\1>", "", text[m.end():m.end() + 3000], flags=re.S))
        after = re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", chunk))).strip()[:200]
        print(f"{subj}\t{url}\t{anchor[:120]} | {after}")
    if not body or "<a" not in text:  # plain-text email
        for u in dict.fromkeys(re.findall(r"https?://[^\s<>\"')]+", text)):
            u = clean(u)
            if not JUNK.search(u):
                print(f"{subj}\t{u}\t")
