#!/usr/bin/env python3
"""WCAG AA contrast gate for prdforge theme families.

Usage:
  check_contrast.py <file.html> [<file.html> ...] [--all]
Reads the token blocks out of a built page or shell (prd-template.html, a -prd.html,
a -plan-share.html, a bundle): the project-f base (:root[data-theme="light"|"dark"]) and
every :root[data-family="x"] family with its dark override. By default it checks the
family the document names in data-family on <html>; --all checks every family found.

Text pairs need 4.5:1 (body, muted, links, status colours, pill text, diagram text on
every diagram surface and on the caption panel). Diagram edges need 3:1 against nodes
and the panel. When the page has gantt bars, white bar labels need 4.5:1 on each bar.
Prints one line per family and theme; exit 1 on any failure.
"""
import re, sys

TEXT = [("text", "bg"), ("text", "card"), ("text", "panel"), ("head", "bg"), ("head", "fig"),
        ("muted", "bg"), ("muted", "card"), ("muted", "panel"), ("muted", "fig"),
        ("brand-ink", "bg"), ("brand-ink", "card"), ("brand-ink", "panel"), ("link", "bg"), ("link", "card"),
        ("pass", "card"), ("fail", "card"), ("warn", "card"),
        ("sp", "card"), ("sa", "card"), ("sd", "card"), ("sc", "card"), ("sn", "card"),
        ("dg-text", "dg-node"), ("dg-text", "dg-group"), ("dg-text", "dg-label"), ("dg-text", "fig"),
        ("dg-edge", "dg-group"), ("dg-edge", "fig")]
LINES = [("dg-edge", "dg-node"), ("dg-edge", "fig"), ("brand", "bg")]  # node borders are decorative
BARS = ["bp", "ba", "bd", "bc"]
FALLBACK = {"dg-node": "panel", "dg-node-line": "line2", "dg-text": "head", "dg-edge": "muted",
            "dg-group": "bg", "dg-group-line": "line", "dg-label": "card", "fig": "panel"}


def lum(h):
    h = h.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def ratio(a, b):
    hi, lo = sorted((lum(a), lum(b)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


def tokens(css, selector):
    m = re.search(re.escape(selector) + r"\{([^}]*)\}", css)
    return dict(re.findall(r"--([\w-]+):\s*(#[0-9A-Fa-f]{3,8})\b", m.group(1))) if m else None


def themes(css, fam):
    base_l, base_d = tokens(css, ':root[data-theme="light"]'), tokens(css, ':root[data-theme="dark"]')
    if not base_l or not base_d:
        return None
    if fam == "project-f":
        light, dark = dict(base_l), dict(base_d)
    else:
        fl, fd = tokens(css, f':root[data-family="{fam}"]'), tokens(css, f':root[data-family="{fam}"][data-theme="dark"]')
        if not fl or not fd:
            return None
        light, dark = {**base_l, **fl}, {**base_d, **fd}
    for t in (light, dark):
        for k, v in FALLBACK.items():
            t.setdefault(k, t.get(v))
    return {"light": light, "dark": dark}


def check(doc, fam, t, bars):
    fails, worst = [], 99.0
    for a, b in TEXT:
        if t.get(a) and t.get(b):
            r = ratio(t[a], t[b])
            worst = min(worst, r)
            if r < 4.5:
                fails.append(f"{a} on {b} {r:.2f}")
    for a, b in LINES:
        if t.get(a) and t.get(b) and ratio(t[a], t[b]) < 3:
            fails.append(f"{a} against {b} {ratio(t[a], t[b]):.2f}")
    if bars:
        for k in BARS:
            if t.get(k) and ratio("#FFFFFF", t[k]) < 4.5:
                fails.append(f"white on {k} {ratio('#FFFFFF', t[k]):.2f}")
    return fails, worst


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    every = "--all" in sys.argv
    if not args:
        sys.exit(__doc__)
    bad = 0
    for path in args:
        doc = open(path, encoding="utf-8").read()
        css = "\n".join(re.findall(r"<style[^>]*>([\s\S]*?)</style>", doc)) or doc
        m = re.search(r'<html[^>]*\bdata-family="([a-z-]+)"', doc) or re.search(r'setAttribute\("data-family","([a-z-]+)"\)', doc)
        default = m.group(1) if m else "project-f"
        fams = sorted(set(re.findall(r':root\[data-family="([a-z-]+)"\]\{', css)) | {"project-f"}) if every else [default]
        bars = 'class="g-bar' in doc
        for fam in fams:
            th = themes(css, fam)
            if not th:
                print(f"{path}: {fam}: token blocks not found")
                bad += 1
                continue
            for name, t in th.items():
                fails, worst = check(doc, fam, t, bars)
                tag = " (default)" if fam == default else ""
                print(f"{fam}{tag} {name}: lowest text pair {worst:.2f}:1, {'ok' if not fails else 'FAIL ' + '; '.join(fails)}")
                bad += bool(fails)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
