#!/usr/bin/env python3
"""
Render a PRD review report (JSON) into a self-contained, shareable HTML scorecard.

Usage:
    python3 render.py report.json out.html      # explicit in/out
    python3 render.py report.json               # writes report's HTML to stdout
    cat report.json | python3 render.py - out.html

The JSON schema is documented in references/report-schema.md. Unknown fields are ignored;
missing optional fields degrade gracefully. Output is brand-neutral, works offline, and
supports light/dark.
"""
import sys, json, html, math

CSS = r"""
:root{--bg:#fbfbfc;--surface:#ffffff;--surface-2:#f1f3f5;--ink:#1c2126;--muted:#5b636e;--faint:#9aa1ab;
--line:#e6e8ec;--line-strong:#d3d7dd;--accent:#3d5a80;--good:#1f7a4d;--good-soft:#e7f1ea;--warn:#9a6410;
--warn-soft:#f5ecdb;--bad:#b23c33;--bad-soft:#f6e8e6;--shadow:0 1px 2px rgba(20,25,30,.05),0 6px 18px rgba(20,25,30,.05);
--radius:7px;--sans:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
--mono:"SF Mono","JetBrains Mono",Menlo,Consolas,"Roboto Mono",ui-monospace,monospace}
@media (prefers-color-scheme:dark){:root{--bg:#14171c;--surface:#1b1f26;--surface-2:#232830;--ink:#e8eaed;
--muted:#a0a7b2;--faint:#6f7783;--line:#2a2f38;--line-strong:#3a414c;--accent:#8aa6cc;--good:#4fbf85;
--good-soft:#123020;--warn:#d59a4e;--warn-soft:#2c2517;--bad:#e0796f;--bad-soft:#391e1b;
--shadow:0 1px 2px rgba(0,0,0,.3),0 10px 30px rgba(0,0,0,.35)}}
:root[data-theme="light"]{--bg:#fbfbfc;--surface:#ffffff;--surface-2:#f1f3f5;--ink:#1c2126;--muted:#5b636e;--faint:#9aa1ab;--line:#e6e8ec;--line-strong:#d3d7dd;--accent:#3d5a80;--good:#1f7a4d;--good-soft:#e7f1ea;--warn:#9a6410;--warn-soft:#f5ecdb;--bad:#b23c33;--bad-soft:#f6e8e6}
:root[data-theme="dark"]{--bg:#14171c;--surface:#1b1f26;--surface-2:#232830;--ink:#e8eaed;--muted:#a0a7b2;--faint:#6f7783;--line:#2a2f38;--line-strong:#3a414c;--accent:#8aa6cc;--good:#4fbf85;--good-soft:#123020;--warn:#d59a4e;--warn-soft:#2c2517;--bad:#e0796f;--bad-soft:#391e1b}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font-family:var(--sans);font-size:16px;line-height:1.55;-webkit-font-smoothing:antialiased}
.wrap{max-width:820px;margin:0 auto;padding:28px clamp(18px,4vw,36px) 90px}
.top{display:flex;align-items:center;gap:12px;margin-bottom:22px}
.top .mark{width:36px;height:36px;border-radius:8px;background:var(--accent);color:#fff;display:grid;place-items:center;font-weight:800;font-size:18px;flex:none}
.top h1{margin:0;font-size:1.3rem;letter-spacing:-.01em}
.top .sub{font-family:var(--mono);font-size:12px;color:var(--muted);margin-top:2px}
.top .toggle{margin-left:auto;display:inline-flex;align-items:center;gap:7px;font-family:var(--mono);font-size:11px;letter-spacing:.06em;text-transform:uppercase;color:var(--muted);background:var(--surface);border:1px solid var(--line);border-radius:99px;padding:7px 12px;cursor:pointer}
.top .toggle .moon{width:12px;height:12px;border-radius:50%;border:1.5px solid currentColor;background:linear-gradient(90deg,currentColor 0 50%,transparent 50% 100%)}
.card{background:var(--surface);border:1px solid var(--line);border-radius:var(--radius);box-shadow:var(--shadow);margin-bottom:18px}
.overall{display:flex;align-items:center;gap:22px;padding:20px}
.ring{position:relative;width:120px;height:120px;flex:none}
.ring svg{transform:rotate(-90deg)}
.ring .val{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center}
.ring .num{font-weight:800;font-size:2.6rem;line-height:1;font-variant-numeric:tabular-nums}
.ring .den{font-family:var(--mono);font-size:11px;color:var(--faint);margin-top:2px}
.vd .grade{display:inline-block;font-family:var(--mono);font-weight:700;font-size:12px;letter-spacing:.08em;text-transform:uppercase;padding:3px 10px;border-radius:99px;margin-bottom:8px}
.vd h2{margin:0 0 6px;font-size:1.15rem}
.vd p{margin:0;color:var(--muted);font-size:14px}
.baseline{padding:0 20px 18px;font-size:13px;color:var(--muted)}
.baseline b{color:var(--ink)}
.sect-h{font-family:var(--mono);font-size:11px;letter-spacing:.09em;text-transform:uppercase;color:var(--muted);font-weight:700;padding:16px 20px 4px}
.cats{padding:4px 20px 14px}
.cat{padding:11px 0;border-bottom:1px dashed var(--line)}
.cat:last-child{border-bottom:none}
.cat .cr{display:flex;justify-content:space-between;align-items:baseline;gap:10px;margin-bottom:6px}
.cat .cn{font-weight:700;font-size:14px}
.cat .cs{font-family:var(--mono);font-size:12.5px;color:var(--muted);font-variant-numeric:tabular-nums}
.bar{height:7px;border-radius:99px;background:var(--surface-2);overflow:hidden}
.bar>i{display:block;height:100%;border-radius:99px}
.cat .cnote{font-size:12.5px;color:var(--muted);margin-top:6px}
.rw{display:flex;gap:12px;padding:14px 20px;border-top:1px solid var(--line)}
.rw:first-of-type{border-top:none}
.rw .rwn{flex:none;width:22px;height:22px;border-radius:50%;background:var(--accent);color:#fff;display:grid;place-items:center;font-size:12px;font-weight:700;margin-top:1px}
.rw .rwb{flex:1;min-width:0}
.ba{font-size:14px;margin-bottom:7px}
.ba .tag{display:inline-block;font-family:var(--mono);font-size:9.5px;font-weight:700;letter-spacing:.06em;text-transform:uppercase;padding:2px 7px;border-radius:99px;margin-right:8px;vertical-align:1px}
.tag.before{background:var(--bad-soft);color:var(--bad)}
.tag.after{background:var(--good-soft);color:var(--good)}
.why{font-size:12.5px;color:var(--muted)}
.fixes{padding:10px 20px 18px 42px;margin:0;list-style-position:outside}
.fixes li{margin:9px 0;padding-left:6px;font-size:14px;line-height:1.5}
.fixes li::marker{color:var(--accent);font-weight:700;font-family:var(--mono);font-size:12.5px}
.findings{padding:4px 20px 18px}
.f{display:flex;gap:10px;padding:9px 0;border-top:1px solid var(--line);font-size:13.5px}
.f:first-of-type{border-top:none}
.f .chip{flex:none;font-family:var(--mono);font-size:9.5px;font-weight:700;letter-spacing:.06em;text-transform:uppercase;padding:2px 7px;border-radius:99px;height:fit-content;margin-top:1px;color:#fff}
.chip.fail{background:var(--bad)}.chip.warn{background:var(--warn)}.chip.pass{background:var(--good)}
.f .ref{color:var(--faint);font-family:var(--mono);font-size:11px;margin-left:6px}
.note{font-size:12px;color:var(--faint);text-align:center;padding:8px 20px 0}
"""

SCRIPT = """
(function(){var r=document.documentElement,b=document.getElementById('tg');
b.addEventListener('click',function(){var c=r.getAttribute('data-theme');
if(!c)c=matchMedia('(prefers-color-scheme: dark)').matches?'dark':'light';
r.setAttribute('data-theme',c==='dark'?'light':'dark');});})();
"""


def esc(s):
    return html.escape(str(s))


def band(r):
    return "var(--good)" if r >= .85 else "var(--warn)" if r >= .6 else "var(--bad)"


def grade_style(total):
    if total >= 80:
        return ("var(--good)", "var(--good-soft)")
    if total >= 55:
        return ("var(--warn)", "var(--warn-soft)")
    return ("var(--bad)", "var(--bad-soft)")


def render(d):
    total = d.get("total", 0)
    grade = d.get("grade", "")
    gc, gbg = grade_style(total)
    C = 2 * math.pi * 52
    off = C * (1 - total / 100.0)
    ringcol = band(total / 100.0)
    title = esc(d.get("title", "PRD review"))

    cats = ""
    for c in d.get("cats", []):
        ratio = c["score"] / c["max"] if c.get("max") else 0
        note = esc(c.get("note", ""))
        cats += ('<div class="cat"><div class="cr">'
                 f'<span class="cn">{esc(c["name"])}</span>'
                 f'<span class="cs">{round(c["score"],1)} / {c["max"]}</span></div>'
                 f'<div class="bar"><i style="width:{ratio*100:.0f}%;background:{band(ratio)}"></i></div>'
                 + (f'<div class="cnote">{note}</div>' if note else '') + '</div>')

    rewrites = ""
    for i, r in enumerate(d.get("rewrites", []), 1):
        rewrites += ('<div class="rw">'
                     f'<div class="rwn">{i}</div><div class="rwb">'
                     f'<div class="ba"><span class="tag before">Before</span>{esc(r.get("before",""))}</div>'
                     f'<div class="ba"><span class="tag after">After</span>{esc(r.get("after",""))}</div>'
                     + (f'<div class="why">Why: {esc(r["why"])}</div>' if r.get("why") else '')
                     + '</div></div>')

    fixes = "".join(f'<li>{esc(x)}</li>' for x in d.get("topFixes", []))

    order = {"fail": 0, "warn": 1, "pass": 2}
    findings = ""
    for f in sorted(d.get("findings", []), key=lambda f: order.get(f.get("level"), 3)):
        lvl = esc(f.get("level", "warn"))
        ref = esc(f.get("ref", ""))
        findings += (f'<div class="f"><span class="chip {lvl}">{lvl}</span>'
                     f'<span class="ft">{esc(f.get("msg",""))}'
                     + (f' <span class="ref">{ref}</span>' if ref else '') + '</span></div>')

    baseline = ""
    if d.get("baseline") is not None:
        baseline = (f'<div class="baseline">Structural baseline '
                    f'<b>{esc(d.get("baseline"))}/100</b> from the linter'
                    + (f'; adjusted to <b>{total}</b> because {esc(d["adjustmentNote"])}' if d.get("adjustmentNote") else '')
                    + '.</div>')

    body = (
        '<div class="wrap">'
        '<div class="top"><span class="mark">✓</span><div><h1>' + title + '</h1>'
        '<div class="sub">PRD scorecard</div></div>'
        '<button class="toggle" id="tg" aria-label="Toggle theme"><span class="moon"></span>Theme</button></div>'
        '<div class="card"><div class="overall">'
        '<div class="ring"><svg width="120" height="120" viewBox="0 0 120 120">'
        '<circle cx="60" cy="60" r="52" fill="none" stroke="var(--surface-2)" stroke-width="10"/>'
        f'<circle cx="60" cy="60" r="52" fill="none" stroke="{ringcol}" stroke-width="10" stroke-linecap="round" '
        f'stroke-dasharray="{C:.1f}" stroke-dashoffset="{off:.1f}"/></svg>'
        f'<div class="val"><span class="num">{total}</span><span class="den">/ 100</span></div></div>'
        f'<div class="vd"><span class="grade" style="color:{gc};background:{gbg}">Grade {esc(grade)}</span>'
        f'<h2>{esc(d.get("verdict",""))}</h2><p>{esc(d.get("detail",""))}</p></div></div>'
        + baseline + '</div>'
        '<div class="card"><div class="sect-h">Category scores</div><div class="cats">' + cats + '</div></div>'
        + ('<div class="card"><div class="sect-h">Weakest requirements, rewritten</div>' + rewrites + '</div>' if rewrites else '')
        + ('<div class="card"><div class="sect-h">Top fixes</div><ol class="fixes">' + fixes + '</ol></div>' if fixes else '')
        + ('<div class="card"><div class="sect-h">All findings</div><div class="findings">' + findings + '</div></div>' if findings else '')
        + '<div class="note">Heuristic + semantic review. A high score means well-formed, not necessarily the right product.</div>'
        '</div>'
    )

    return ('<!doctype html><html><head><meta charset="utf-8">'
            f'<title>{title} — PRD scorecard</title>'
            '<meta name="viewport" content="width=device-width, initial-scale=1">'
            '<style>' + CSS + '</style></head><body>' + body
            + '<script>' + SCRIPT + '</script></body></html>')


def main():
    if len(sys.argv) < 2 or sys.argv[1] == '-':
        data = json.load(sys.stdin)
        out = sys.argv[2] if len(sys.argv) > 2 else None
    else:
        with open(sys.argv[1], encoding='utf-8') as f:
            data = json.load(f)
        out = sys.argv[2] if len(sys.argv) > 2 else None
    doc = render(data)
    if out:
        with open(out, 'w', encoding='utf-8') as f:
            f.write(doc)
        print("wrote " + out)
    else:
        sys.stdout.write(doc)


if __name__ == "__main__":
    main()
