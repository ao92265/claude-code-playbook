#!/usr/bin/env python3
"""Wrap converted body in the styled shell (theme family from ../prd-template.html, whose data-family sets the default).

Usage: assemble.py <config.json> <workdir>

The workdir holds body.html and receives the two outputs. Everything specific
to one document (titles, figure labels, gantt data, stat tiles, artwork) comes
from the config file, so the shell below is reusable as it stands.

Transforms, in order: mermaid unfence, contents -> sidebar nav, chapter h2
kickers (act + chapter number), stream tokens -> pills, gates table -> gate
cards, week table classing, generic table wrapping. Fails loudly if any
anchor pattern drifts. No em or en dashes may survive to the output.
"""
import base64
import html as H
import json
import os
import re
import subprocess
import sys
import tempfile


def die(msg):
    sys.exit(f"ASSEMBLE FAIL: {msg}")


def need(obj, key, where="config"):
    """Read a required config value. Never defaults: a missing key is a fail,
    named by key, because a silent default would ship the wrong document.
    The schema pass below has already caught this; these reads are a backstop."""
    if not isinstance(obj, dict) or key not in obj:
        die(f"{where}.{key} missing from the config")
    return obj[key]


# ── 0. the config schema ──
# Every required key is declared here and checked in one pass before any body
# work starts, so a config typo is reported as a config typo. Read lazily
# instead, a missing key surfaces halfway through the build as whatever the
# next step happened to fail on: a stats typo would come back as "expected 3
# mermaid blocks, got 0" on a machine with no mmdc installed. One pass also
# means one run reports every problem in the file rather than the first.
# Unlisted keys are left alone: inject.py reads its own block from this file.
STR, NUM, INT = "string", "number", "whole number"
KIND = {
    STR: lambda v: isinstance(v, str),
    # bools are ints in Python, and "weeks": true is a config error, not a 1
    NUM: lambda v: isinstance(v, (int, float)) and not isinstance(v, bool),
    INT: lambda v: isinstance(v, int) and not isinstance(v, bool),
}

# A gantt row comes in three shapes, told apart by which key is present:
# a section heading, a hand-placed raw bar, or a plain week span.
GANTT_ROW = ("variant", {
    "section": {"section": STR, "class": STR},
    "html": {"id": STR, "name": STR, "html": STR},
    None: {"id": STR, "name": STR, "class": STR, "from": NUM, "to": NUM},
})

SCHEMA = {
    "slug": STR,
    "title": STR,
    "nav_brand": STR,
    "nav_subtitle": STR,
    "chapter_count": INT,
    "gate_count": INT,
    "acts": ("list", ("object", {"first": INT, "last": INT, "name": STR})),
    "figure_labels": ("list", STR),
    "stream_pills": ("map", STR),
    "stats": ("list", ("object", {"value": STR, "caption": STR})),
    "hero": ("object", {"meta": ("list", STR), "summary": STR}),
    "artwork_dir": STR,
    "hero_art": ("object", {"name": STR, "alt": STR}),
    "divider_art": ("list", ("object", {"chapter": INT, "name": STR, "alt": STR})),
    "gantt": ("object", {
        "weeks": INT,
        "tail_pct": NUM,
        "tail_label": STR,
        "week_row_label": STR,
        "gate_row_label": STR,
        "aria_label": STR,
        "bands": ("list", ("object", {"left": STR, "width": STR, "label": STR})),
        "gates": ("list", ("object", {"week": NUM, "label": STR})),
        "rows": ("list", GANTT_ROW),
        "legend": ("list", ("object", {"class": STR, "label": STR})),
    }),
}

# Ranges the shape alone cannot express, checked in the same pass.
BOUNDS = [
    ("chapter_count", lambda v: v >= 1, "must be at least 1"),
    ("gate_count", lambda v: v >= 1, "must be at least 1"),
    ("figure_labels", lambda v: len(v) >= 1, "must list at least one figure label"),
    ("stream_pills", lambda v: len(v) >= 1,
     "must map at least one token to a pill class"),
    ("acts", lambda v: len(v) >= 1, "must list at least one act"),
    ("stats", lambda v: 3 <= len(v) <= 6, "must list 3 to 6 stat tiles"),
    ("hero.meta", lambda v: len(v) >= 1, "must list at least one meta item (date, PRD version cited)"),
    ("hero.summary", lambda v: 0 < len(v) <= 200, "must be one line, 200 characters at most"),
    ("gantt.weeks", lambda v: v >= 1, "must be a positive whole number of weeks"),
    ("gantt.tail_pct", lambda v: 0 <= v < 100, "must be a percentage below 100"),
    ("gantt.rows", lambda v: len(v) >= 1, "must list at least one row"),
]


def check(val, spec, where, errs):
    """Walk one schema node, appending a line per problem instead of dying, so
    the caller can report the whole file at once."""
    if isinstance(spec, str):
        if not KIND[spec](val):
            errs.append(f"{where} must be a {spec}")
        return
    kind, arg = spec
    if kind == "object":
        if not isinstance(val, dict):
            errs.append(f"{where} must be a JSON object")
            return
        for k, sub in arg.items():
            if k not in val:
                errs.append(f"{where}.{k} missing from the config")
            else:
                check(val[k], sub, f"{where}.{k}", errs)
    elif kind == "list":
        if not isinstance(val, list):
            errs.append(f"{where} must be a list")
            return
        for i, item in enumerate(val):
            check(item, arg, f"{where}[{i}]", errs)
    elif kind == "map":
        if not isinstance(val, dict):
            errs.append(f"{where} must be a JSON object")
            return
        for k, v in val.items():
            check(v, arg, f"{where}.{k}", errs)
    elif kind == "variant":
        if not isinstance(val, dict):
            errs.append(f"{where} must be a JSON object")
            return
        for disc, sub in arg.items():
            if disc is None or disc in val:
                check(val, ("object", sub), where, errs)
                return


def validate(cfg, path):
    errs = []
    check(cfg, ("object", SCHEMA), "config", errs)

    def dig(dotted):
        cur = cfg
        for part in dotted.split("."):
            if not isinstance(cur, dict) or part not in cur:
                return None
            cur = cur[part]
        return cur

    for dotted, ok, why in BOUNDS:
        v = dig(dotted)
        if v is None:
            continue           # already reported as missing
        try:
            good = ok(v)
        except TypeError:
            continue           # already reported as the wrong type
        if not good:
            errs.append(f"config.{dotted} {why}")

    if errs:
        die(f"{len(errs)} problem(s) in {path}:\n  " + "\n  ".join(errs))


# ── 0b. arguments: the config file and the working directory ──
if len(sys.argv) != 3:
    die("usage: assemble.py <config.json> <workdir>")
CFG_PATH, DIR = sys.argv[1], sys.argv[2].rstrip("/") or "/"
try:
    with open(CFG_PATH, encoding="utf-8") as fh:
        CFG = json.load(fh)
except OSError as e:
    die(f"cannot read config {CFG_PATH}: {e}")
except json.JSONDecodeError as e:
    die(f"config {CFG_PATH} is not valid JSON: {e}")
if not isinstance(CFG, dict):
    die(f"config {CFG_PATH} must be a JSON object at the top level")
validate(CFG, CFG_PATH)
if not os.path.isdir(DIR):
    die(f"workdir is not a directory: {DIR}")
try:
    with open(f"{DIR}/body.html", encoding="utf-8") as fh:
        body = fh.read()
except OSError as e:
    die(f"cannot read {DIR}/body.html: {e}")

SLUG = need(CFG, "slug")
TITLE = need(CFG, "title")
NAV_BRAND = need(CFG, "nav_brand")
NAV_SUBTITLE = need(CFG, "nav_subtitle")

# ── 1. mermaid: escaped code fence -> baked inline <svg> ──
# The page must render with nothing but a browser: a standalone copy gets
# emailed, so there is no claude.ai artifact runtime to turn pre.mermaid into
# pictures. mmdc renders each diagram at build time against a sentinel palette
# whose colours are then swapped for the page's own CSS tokens, so one SVG
# follows light, dark and the in-page flip button with no JavaScript.
# One label per diagram, in document order: the count is the expected number
# of mermaid blocks.
FIG_LABELS = need(CFG, "figure_labels")

# sentinel -> page token. Sentinels are greppable and nothing else uses them.
FIG_TOKENS = {
    "#f01f01": "var(--dg-node, var(--panel))",        # node fill
    "#f01f02": "var(--dg-node-line, var(--line2))",   # node border
    "#f01f03": "var(--dg-text, var(--head))",         # node text
    "#f01f04": "var(--dg-edge, var(--muted))",        # edges, arrowhead markers
    "#f01f06": "var(--dg-group, var(--bg))",          # subgraph fill
    "#f01f07": "var(--dg-group-line, var(--line))",   # subgraph border
    "#f01f08": "var(--dg-label, var(--card))",        # edge-label background
    "rgba(240, 31, 8, 0.5)": "var(--dg-label, var(--card))",  # derived edge-label background
    "#a11101": "var(--dg-edge, var(--muted))",        # subgraph title
    "#a11105": "var(--dg-edge, var(--muted))",        # arrowheadPath (legacy selector)
    "#a11106": "var(--dg-node, var(--panel))",        # error box, never rendered
    "#a11107": "var(--dg-text, var(--head))",         # error text, never rendered
}
# The diagram tokens (--dg-*) and --fig come from the theme family, so the figures
# take each family's own palette in both themes; project-f falls back to page tokens.

FIG_CFG = json.dumps({"theme": "base", "themeVariables": {
    "primaryColor": "#f01f01", "mainBkg": "#f01f01",
    "primaryBorderColor": "#f01f02", "nodeBorder": "#f01f02",
    "primaryTextColor": "#f01f03", "textColor": "#f01f03",
    "nodeTextColor": "#f01f03",
    "lineColor": "#f01f04",
    "secondaryColor": "#f01f06", "tertiaryColor": "#f01f06",
    "clusterBkg": "#f01f06", "clusterBorder": "#f01f07",
    "edgeLabelBackground": "#f01f08",
    "titleColor": "#a11101", "arrowheadColor": "#a11105",
    "errorBkgColor": "#a11106", "errorTextColor": "#a11107",
    "fontFamily": "system-ui,-apple-system,'Segoe UI',Roboto,"
                  "'Helvetica Neue',Arial,sans-serif",
}})

# Inert defaults mermaid bakes into selectors our diagrams never hit: KaTeX
# glyphs, the neo look, and the two drop-shadow filters (6% black, fine in
# either theme). Anything NOT on this list means an unpinned theme variable.
FIG_INERT = ("#000000", "#000", "rgba(185,185,185,1)")


def bake(m, _n=[0]):
    _n[0] += 1
    i = _n[0]
    if i > len(FIG_LABELS):
        die(f"figure {i} has no entry in config.figure_labels "
            f"({len(FIG_LABELS)} labels for at least {i} mermaid blocks)")
    src = H.unescape(m.group(1))
    with tempfile.TemporaryDirectory() as tmp:
        mmd, cfg, out = f"{tmp}/f.mmd", f"{tmp}/c.json", f"{tmp}/f.svg"
        open(mmd, "w").write(src)
        open(cfg, "w").write(FIG_CFG)
        r = subprocess.run(["mmdc", "-i", mmd, "-o", out, "-b", "transparent",
                            "-c", cfg], capture_output=True, text=True)
        if r.returncode != 0 or not os.path.exists(out):
            die(f"figure {i}: mmdc failed: {r.stderr.strip()[:400]}")
        svg = open(out).read()

    # every id and CSS selector in the file is keyed to "my-svg"; several copies
    # in one document would collide on marker ids
    svg = svg.replace("my-svg", f"fig{i}")
    # edge labels sit at half opacity by default, which greys their text
    svg = svg.replace(".edgeLabel rect{opacity:0.5;", ".edgeLabel rect{opacity:1;")
    for sentinel, token in FIG_TOKENS.items():
        svg = svg.replace(sentinel, token)

    probe = svg
    for inert in FIG_INERT:
        probe = probe.replace(inert, "")
    leaked = re.findall(r"#[0-9a-fA-F]{3,8}\b|rgba?\([^)]*\)", probe)
    if leaked:
        die(f"figure {i}: unthemed colour(s) {sorted(set(leaked))}; "
            "pin the matching mermaid theme variable in FIG_CFG")

    # mmdc pins the natural width inline; let it shrink inside the card
    svg, k = re.subn(r'(<svg id="fig%d"[^>]*?)style="max-width: ([\d.]+)px;'
                     r' background-color: transparent;"' % i,
                     lambda mm: f'{mm.group(1)}aria-label="'
                                f'{H.escape(FIG_LABELS[i - 1])}" '
                                f'style="width:100%;height:auto;'
                                f'max-width:{mm.group(2)}px;min-width:'
                                f'{min(620, round(float(mm.group(2))))}px"',
                     svg, count=1)
    if k != 1:
        die(f"figure {i}: root svg style attribute drifted, cannot size it")
    label = H.escape(FIG_LABELS[i - 1])
    return (f'<figure class="fig"><div class="fig-canvas" tabindex="0" role="region" '
            f'aria-label="{label}, scrolls sideways">{svg}</div>'
            f'<figcaption><b>Figure {i}.</b> {label}</figcaption></figure>')


body, n = re.subn(r'<pre><code class="language-mermaid">(.*?)</code></pre>',
                  bake, body, flags=re.S)
if n != len(FIG_LABELS):
    die(f"expected {len(FIG_LABELS)} mermaid blocks, got {n}")
if 'class="mermaid"' in body:
    die("a pre.mermaid survived the bake")

# ── 1b. gantt: built here, injected at the ch8 slot ──
GANTT = need(CFG, "gantt")
GWEEKS = need(GANTT, "weeks", "config.gantt")
GTAIL = need(GANTT, "tail_pct", "config.gantt")  # % of the track after week N
if not isinstance(GWEEKS, int) or GWEEKS < 1:
    die("config.gantt.weeks must be a positive whole number of weeks")
if not 0 <= GTAIL < 100:
    die("config.gantt.tail_pct must be a percentage below 100")
GHEAD = 100.0 - GTAIL          # where the numbered weeks stop
W = GHEAD / GWEEKS             # one programme week, %; the tail owns the rest


def bar(cls, a, b, text="", title=""):
    left, width = a * W, (b - a) * W
    t = f' title="{title}"' if title else ""
    return (f'<div class="g-bar {cls}" style="left:{left:.2f}%;width:{width:.2f}%"{t}>{text}</div>')


def rowbar(r, i):
    """A row's bar: either a week span, or raw html for the hand-placed bars
    that run past the numbered weeks and cannot be expressed as one span."""
    where = f"config.gantt.rows[{i}]"
    if "html" in r:
        return r["html"]
    return bar(need(r, "class", where), need(r, "from", where),
               need(r, "to", where), r.get("text", ""), r.get("title", ""))


def build_gantt():
    head = ("".join(f"<span>{i}</span>" for i in range(GWEEKS)) +
            f'<span class="mo">{need(GANTT, "tail_label", "config.gantt")}</span>')
    phases = "".join(
        f'<div class="g-band" style="left:{need(b, "left", "config.gantt.bands[]")};'
        f'width:{need(b, "width", "config.gantt.bands[]")}">'
        f'{need(b, "label", "config.gantt.bands[]")}</div>'
        for b in need(GANTT, "bands", "config.gantt"))
    gates = "".join(
        f'<span class="g-gate {g.get("class", "")}" '
        f'style="left:{need(g, "week", "config.gantt.gates[]") * W:.2f}%">'
        f'<i></i><em>{need(g, "label", "config.gantt.gates[]")}</em></span>'
        for g in need(GANTT, "gates", "config.gantt"))
    rows = [f'<div class="g-row g-phases"><div class="g-label"></div><div class="g-track">{phases}</div></div>',
            f'<div class="g-row g-head"><div class="g-label">{need(GANTT, "week_row_label", "config.gantt")}</div><div class="g-track">{head}</div></div>',
            f'<div class="g-row g-gaterow"><div class="g-label">{need(GANTT, "gate_row_label", "config.gantt")}</div><div class="g-track">{gates}</div></div>']
    for i, r in enumerate(need(GANTT, "rows", "config.gantt")):
        where = f"config.gantt.rows[{i}]"
        if "section" in r:
            rows.append(f'<div class="g-sec {need(r, "class", where)}">'
                        f'<span class="st">{r["section"]}</span></div>')
        else:
            rows.append(f'<div class="g-row"><div class="g-label"><span><b>{need(r, "id", where)}</b> '
                        f'{need(r, "name", where)}</span></div>'
                        f'<div class="g-track">{rowbar(r, i)}</div></div>')
    legend = ('<div class="g-legend">' + "".join(
        f'<span><i class="{need(l, "class", "config.gantt.legend[]")}"></i>'
        f'{need(l, "label", "config.gantt.legend[]")}</span>'
        for l in need(GANTT, "legend", "config.gantt")) + "</div>")
    return ('<div class="gwrap"><div class="gantt" role="img" aria-label="'
            + H.escape(need(GANTT, "aria_label", "config.gantt")) + '">'
            + "".join(rows) + "</div></div>" + legend)


slot = '<div class="gantt-slot"></div>'
if body.count(slot) != 1:
    die("gantt slot missing")
body = body.replace(slot, build_gantt(), 1)

# ── 2. contents section -> sidebar nav ──
m = re.search(r'<h2>Contents</h2>\n(.*?</em></p>)\n', body, flags=re.S)
if not m:
    die("contents section not found")
toc_raw = m.group(1)
body = body.replace(m.group(0), "", 1)
toc = re.sub(r'<p><strong>(.*?)</strong></p>', r'<div class="nav-group">\1</div>', toc_raw)
toc = re.sub(r'<p><em>(.*?)</em></p>', r'<div class="nav-note">\1</div>', toc, flags=re.S)

# ── 3. chapter h2 -> kicker (act + chapter no) + title ──
# Acts are inclusive chapter ranges, so every chapter number knows its act.
CHAPTERS = need(CFG, "chapter_count")
ACTS = {}
for a in need(CFG, "acts"):
    for i in range(need(a, "first", "config.acts[]"), need(a, "last", "config.acts[]") + 1):
        ACTS[i] = need(a, "name", "config.acts[]")


def chapter(m):
    no, title = int(m.group(1)), m.group(2)
    if no not in ACTS:
        die(f"chapter {no} falls outside every range in config.acts")
    return ('<h2><span class="ch-kicker"><span class="ch-act">' + ACTS[no] +
            '</span><span class="ch-no">Chapter ' + str(no) + '</span></span>'
            '<span class="ch-title">' + title + '</span></h2>')


body, n = re.subn(r'<h2>Chapter (\d+) · (.*?)</h2>', chapter, body, flags=re.S)
if n != CHAPTERS:
    die(f"expected {CHAPTERS} chapter headings, got {n}")

# ── 4. stream tokens -> pills (keep bracket text verbatim) ──
WS_CLS = need(CFG, "stream_pills")
if not WS_CLS:
    die("config.stream_pills must map at least one token to a pill class")


def pill(m):
    w = m.group(1)
    return f'<span class="ws {WS_CLS[w]}">[{w}]</span>'


body = re.sub(r'(?:<strong>)?\[(' + "|".join(re.escape(t) for t in WS_CLS) +
              r')\](?:</strong>)?', pill, body)

# ── 5. gates table -> gate cards ──
GATE_ROWS = need(CFG, "gate_count")
gm = re.search(r'<table>\s*<thead>\s*<tr>\s*<th><strong>Gate</strong></th>.*?</table>',
               body, flags=re.S)
if not gm:
    die("gates table not found")
rows = re.findall(r'<tr>\s*((?:<td>.*?</td>\s*){5})</tr>', gm.group(0), flags=re.S)
if len(rows) != GATE_ROWS:
    die(f"expected {GATE_ROWS} gate rows, got {len(rows)}")
cards = []
for row in rows:
    cells = re.findall(r'<td>(.*?)</td>', row, flags=re.S)
    hm = re.match(r'<strong>Gate (\d+) · (.*?)</strong>\s*(.*)', cells[0], flags=re.S)
    if not hm:
        die("gate title cell drifted: " + cells[0][:60])
    no, name, sub = hm.group(1), hm.group(2), hm.group(3).strip()
    sub_html = f'<div class="gate-sub">{sub}</div>' if sub else ""
    cards.append(f'''<section class="gate">
<header class="gate-head"><span class="gate-no" aria-hidden="true">{no}</span>
<div><div class="gate-name">Gate {no} · {name}</div>{sub_html}</div></header>
<div class="gate-grid">
<div class="gate-cell pass"><div class="gl">What passes</div><p>{cells[1]}</p></div>
<div class="gate-cell fail"><div class="gl">What fails</div><p>{cells[2]}</p></div>
<div class="gate-cell act"><div class="gl">Failure action (pre-written)</div><p>{cells[3]}</p></div>
</div>
<footer class="gate-kill"><span class="gl">Kill call</span><span>{cells[4]}</span></footer>
</section>''')
body = body.replace(gm.group(0), '<div class="gates">' + "\n".join(cards) + "</div>", 1)

# ── 6. week-at-a-glance table gets its own class ──
key = '<table>\n<thead>\n<tr>\n<th><strong>Week</strong></th>'
if body.count(key) != 1:
    die("week table anchor drifted")
body = body.replace(key, key.replace('<table>', '<table class="weekly">'), 1)

# ── 7. remaining tables scroll in their own container ──
body = re.sub(r'<table( class="[^"]*")?>', r'<div class="tbl"><table\1>', body)
body = body.replace("</table>", "</table></div>")

# ── 8. hero band + five-minute version ──
# The plan opens the way the PRD does: a band with a PLAN chip and meta line, the
# big title, a one-line summary and the stat tiles as the same flush card row
# (same classes, same CSS, copied from the PRD shell). The preface paragraphs
# and the hero photo follow; the five-minute panel keeps only its prose.
STATS = need(CFG, "stats")
HERO_CFG = need(CFG, "hero")
stats_html = ('<ul class="stats" aria-label="Key facts">' +
              "".join('<li><div class="stat"><b>'
                      + need(s_, "value", "config.stats[]") + '</b><span>'
                      + need(s_, "caption", "config.stats[]") + '</span></div></li>'
                      for s_ in STATS) + "</ul>")

hm = re.search(r"<h1>(.*?)</h1>", body, flags=re.S)
if not hm or body.count("<h1>") != 1:
    die("plan title anchor drifted: expected exactly one <h1> at the top of the body")
hero_html = ('<header class="hero"><p class="hero-kicker"><span class="k-doc">PLAN</span>'
             + "".join(f"<span>{H.escape(m)}</span>" for m in need(HERO_CFG, "meta", "config.hero"))
             + f'</p><h1>{hm.group(1)}</h1><p class="hero-sum">{H.escape(need(HERO_CFG, "summary", "config.hero"))}</p>'
             + stats_html + "</header>")
body = body[:hm.start()] + hero_html + body[hm.end():]

tm = re.search(r'<p><a id="tldr"></a></p>\s*<h2>The five-minute version</h2>(.*?)(?=<!-- ═+ CHAPTER 1)',
               body, flags=re.S)
if not tm:
    die("tldr section not found")
inner = tm.group(1)
# the inject step still marks the old tile slot inside the panel; the tiles now
# live in the hero band, so the slot must exist once and is dropped here
if inner.count('<div class="tldr-stats"></div>') != 1:
    die("tldr stats slot missing")
inner = inner.replace('<div class="tldr-stats"></div>', "", 1)
tldr_html = ('<section class="tldr" aria-label="The five-minute version">'
             '<p><a id="tldr"></a></p>'
             '<h2><span class="ch-kicker"><span class="ch-act">Start here</span>'
             '<span class="ch-no">A five-minute read</span></span>'
             '<span class="ch-title">The five-minute version</span></h2>'
             '<div class="tldr-body">' + inner + '</div></section>')
body = body[:tm.start()] + tldr_html + body[tm.end():]

# ── 9. artwork: hero above the TLDR, dividers above the act breaks ──
# Every image is inlined as a data URI so the emailed copy carries its own
# pictures. A missing file is a build failure, never a silent gap.
IMGDIR = need(CFG, "artwork_dir").rstrip("/")


def art(name, alt):
    try:
        raw = open(f"{IMGDIR}/{name}.jpg", "rb").read()
    except FileNotFoundError:
        die(f"artwork missing: {IMGDIR}/{name}.jpg")
    uri = "data:image/jpeg;base64," + base64.b64encode(raw).decode()
    return f'<figure class="art"><img src="{uri}" alt="{alt}" loading="lazy"></figure>'


HERO = need(CFG, "hero_art")
hero_anchor = '<section class="tldr"'
if body.count(hero_anchor) != 1:
    die("tldr anchor for hero art missing")
body = body.replace(hero_anchor,
                    art(need(HERO, "name", "config.hero_art"),
                        need(HERO, "alt", "config.hero_art")) + hero_anchor, 1)

# the opening must read band, stat row, preface, photo, five-minute panel
_order = [body.find('<header class="hero">'), body.find('<ul class="stats"'), body.find("</header>"),
          body.find('<figure class="art">'), body.find('<section class="tldr"')]
if (-1 in _order or _order != sorted(_order) or body.count('<header class="hero">') != 1
        or body[_order[1]:_order[2]].count('<div class="stat">') != len(STATS)):
    die("hero band or its stat row is missing or out of order (want band, stats, preface, photo, tldr)")

for d in need(CFG, "divider_art"):
    no = need(d, "chapter", "config.divider_art[]")
    dm = re.search(rf'<!-- ═+ CHAPTER {no} ═+ -->', body)
    if not dm:
        die(f"chapter {no} comment for divider art missing")
    piece = art(need(d, "name", "config.divider_art[]"),
                need(d, "alt", "config.divider_art[]"))
    body = body[:dm.end()] + piece + body[dm.end():]

# ── theme family: tokens and default come from the PRD shell, one source ──
# prd-template.html holds every family's tokens between the families markers and
# names the default in data-family on its <html>. Changing that one value moves
# the PRD, the bundle and this plan together. project-f stays a switch.
_TPL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "prd-template.html")
try:
    _tpl = open(_TPL, encoding="utf-8").read()
except OSError as e:
    die(f"cannot read theme families from {_TPL}: {e}")
_fm = re.search(r"/\* families:start[\s\S]*?/\* families:end \*/", _tpl)
_dm = re.search(r'<html[^>]*\bdata-family="([a-z-]+)"', _tpl)
if not _fm or not _dm:
    die("prd-template.html lost its families block or its data-family default")
FAMILIES_CSS, FAMILY = _fm.group(0), _dm.group(1)
_hm = re.search(r"/\* hero:start[\s\S]*?/\* hero:end \*/", _tpl)
if not _hm:
    die("prd-template.html lost its hero block (hero:start / hero:end markers)")
HERO_CSS = _hm.group(0)

# ── tokens: light + dark defined once, reused for data-theme overrides ──
LIGHT = """
  --bg:#FFFFFF; --panel:#F6F9FC; --card:#FCFDFE; --line:#E3ECF7; --line2:#D4DEE9;
  --head:#061B31; --text:#30313D; --muted:#596A7B;
  --brand:#635BFF; --brand-ink:#4F45E4; --link:#0570DE;
  --pass:#007B55; --fail:#B3213F; --warn:#9A6700;
  --sp:#5348E8; --sa:#007B55; --sd:#B4540A; --sc:#0264C7; --sn:#596A7B;
  --bp:#5348E8; --ba:#007B55; --bd:#B4540A; --bc:#0264C7;
  --shadow:0 1px 2px rgba(6,27,49,.05), 0 8px 24px rgba(6,27,49,.05);
  --fig:#EEF3FB;
"""
DARK = """
  --bg:#0B1526; --panel:#121F32; --card:#0F1A2B; --line:#233449; --line2:#31445E;
  --head:#F2F6FB; --text:#C9D4E3; --muted:#8DA0B6;
  --brand:#857CFF; --brand-ink:#A29BFF; --link:#62A9F5;
  --pass:#34C08B; --fail:#F2698C; --warn:#E0A93E;
  --sp:#A29BFF; --sa:#3ECF9B; --sd:#F0925A; --sc:#6FB5F7; --sn:#8DA0B6;
  --bp:#6A5FF0; --ba:#0B7A58; --bd:#A9531A; --bc:#1F6FC0;
  --shadow:0 1px 2px rgba(0,0,0,.3), 0 8px 24px rgba(0,0,0,.25);
  --fig:#15233A;
"""

# The gantt column rules are sized from the configured week count, so the three
# widths that depend on it are placeholders swapped in below rather than the
# percentages one particular programme length happened to need.
CSS = """
:root{""" + LIGHT + """}
@media (prefers-color-scheme: dark){ :root{""" + DARK + """} }
:root[data-theme="dark"]{""" + DARK + """}
:root[data-theme="light"]{""" + LIGHT + """}
""" + FAMILIES_CSS + """
*{box-sizing:border-box}
html{scroll-behavior:smooth}
@media (prefers-reduced-motion: reduce){ html{scroll-behavior:auto} *{transition:none!important} }
body{
  margin:0; background:var(--bg); color:var(--text);
  font-family:system-ui,-apple-system,'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif;
  font-size:16px; line-height:1.68;
  -webkit-font-smoothing:antialiased; text-rendering:optimizeLegibility;
}
code, .mono{font-family:ui-monospace,'SF Mono','Cascadia Code','Source Code Pro',Menlo,Consolas,monospace}
::selection{background:color-mix(in srgb, var(--brand) 22%, transparent)}
a{color:var(--link); text-decoration-thickness:1px; text-underline-offset:2.5px}
a[id]{scroll-margin-top:28px}
.layout{display:flex; max-width:1800px; margin:0 auto}

/* ── sidebar ── */
nav.side{
  position:sticky; top:0; align-self:flex-start; height:100vh; overflow-y:auto;
  width:272px; flex-shrink:0; padding:28px 18px 28px 24px;
  border-right:1px solid var(--line); font-size:.82rem; scrollbar-width:thin;
}
.nav-brand{padding:0 10px 14px; border-bottom:1px solid var(--line); margin-bottom:10px}
.nav-brand .nb-t{font-weight:650; font-size:.95rem; color:var(--head); letter-spacing:-.01em}
.nav-brand .nb-d{font-family:ui-monospace,'SF Mono',Menlo,Consolas,monospace;
  font-size:.66rem; color:var(--muted); letter-spacing:.06em; text-transform:uppercase; margin-top:3px}
.nav-group{
  font-family:ui-monospace,'SF Mono',Menlo,Consolas,monospace;
  font-size:.64rem; font-weight:600; letter-spacing:.1em; text-transform:uppercase;
  color:var(--muted); margin:16px 0 4px; padding:0 10px;
}
nav.side ul{list-style:none; margin:0; padding:0}
nav.side li{margin:0}
nav.side a{
  display:block; color:var(--muted); text-decoration:none; padding:4px 10px;
  border-radius:7px; line-height:1.4;
  transition:background 120ms cubic-bezier(.23,1,.32,1), color 120ms cubic-bezier(.23,1,.32,1);
}
nav.side a:hover{background:var(--panel); color:var(--head)}
nav.side a.on{background:color-mix(in srgb, var(--brand) 10%, transparent); color:var(--brand-ink); font-weight:600}
.nav-note{color:var(--muted); font-size:.68rem; line-height:1.5; margin-top:18px; padding:12px 10px 0; border-top:1px solid var(--line)}

/* ── main column ── */
/* The right gutter is floored above the width of the fixed #themeflip button
   (36px wide at right:18px). Without that floor the button paints over the
   body text and hides the tail of every line that scrolls under it. */
main{flex:1; min-width:0; max-width:1180px;
  padding:44px max(clamp(20px, 2vw, 48px), 64px) 110px clamp(20px, 2vw, 48px)}
li{margin:.32rem 0}
strong{font-weight:625; color:var(--head)}
hr{border:none; border-top:1px solid var(--line); margin:3rem 0}
h1{
  font-size:clamp(2rem,3.2vw,2.7rem); font-weight:650; letter-spacing:-.028em;
  line-height:1.08; color:var(--head); text-wrap:balance; margin:1.6rem 0 1rem;
}
h1+p{font-size:1.11rem; color:var(--muted); line-height:1.6}
h2{margin:4.2rem 0 1.1rem; padding-top:2.4rem; border-top:1px solid var(--line)}
.ch-kicker{
  display:flex; gap:.9em; align-items:baseline;
  font-family:ui-monospace,'SF Mono',Menlo,Consolas,monospace;
  font-size:.7rem; font-weight:600; letter-spacing:.09em; text-transform:uppercase;
}
.ch-kicker .ch-act{color:var(--muted)}
.ch-kicker .ch-no{color:var(--brand-ink)}
.ch-title{
  display:block; font-size:1.62rem; font-weight:650; letter-spacing:-.02em;
  line-height:1.22; color:var(--head); text-wrap:balance; margin-top:.35rem;
}
h3{font-size:1.17rem; font-weight:650; letter-spacing:-.012em; color:var(--head);
  line-height:1.3; margin:2.3rem 0 .6rem; text-wrap:balance}
h4{font-size:1rem; font-weight:650; color:var(--head); margin:1.8rem 0 .5rem}
code{font-size:.86em; background:var(--panel); border:1px solid var(--line);
  padding:.08em .34em; border-radius:5px; color:var(--head)}
blockquote{
  margin:1.6rem 0; padding:1.05rem 1.4rem;
  background:var(--panel); border:1px solid var(--line); border-radius:10px;
}
blockquote p{margin:.5rem 0}

/* ── the five-minute version ── */
.tldr{margin:2.8rem 0 0; padding:1.9rem 2.1rem 1.5rem; border:1px solid var(--line2);
  border-radius:14px; background:var(--card); box-shadow:var(--shadow);
  position:relative; overflow:hidden}
.tldr::before{content:""; position:absolute; top:0; left:0; right:0; height:3px;
  background:linear-gradient(90deg, var(--sp), var(--sc) 40%, var(--sa) 72%, var(--sd))}
.tldr h2{margin:0 0 1.25rem; padding-top:0; border-top:none}
.tldr .ch-title{font-size:1.42rem}
""" + HERO_CSS + """
.tldr-body{column-width:30rem; column-gap:3.2rem; orphans:3; widows:3}
.tldr-body p{font-size:.95rem; line-height:1.62; margin:.6rem 0}
.tldr-body p:first-child{margin-top:0}

/* ── stream pills ── */
.ws{
  font-family:ui-monospace,'SF Mono',Menlo,Consolas,monospace;
  font-size:.72rem; font-weight:600; letter-spacing:.02em;
  padding:.08rem .44rem; border-radius:6px; white-space:nowrap; vertical-align:baseline;
}
.ws.p{color:var(--sp); background:color-mix(in srgb, var(--sp) 10%, transparent); border:1px solid color-mix(in srgb, var(--sp) 28%, transparent)}
.ws.a{color:var(--sa); background:color-mix(in srgb, var(--sa) 10%, transparent); border:1px solid color-mix(in srgb, var(--sa) 28%, transparent)}
.ws.d{color:var(--sd); background:color-mix(in srgb, var(--sd) 10%, transparent); border:1px solid color-mix(in srgb, var(--sd) 28%, transparent)}
.ws.c{color:var(--sc); background:color-mix(in srgb, var(--sc) 10%, transparent); border:1px solid color-mix(in srgb, var(--sc) 28%, transparent)}
.ws.all{color:var(--sn); background:color-mix(in srgb, var(--sn) 10%, transparent); border:1px solid color-mix(in srgb, var(--sn) 28%, transparent)}

/* ── tables ── */
.tbl{overflow-x:auto; margin:1.5rem 0; border:1px solid var(--line);
  border-radius:10px; background:var(--card); box-shadow:var(--shadow)}
table{border-collapse:collapse; width:100%; font-size:.9rem; font-variant-numeric:tabular-nums}
th{
  font-family:ui-monospace,'SF Mono',Menlo,Consolas,monospace;
  text-align:left; font-size:.68rem; font-weight:600; letter-spacing:.07em;
  text-transform:uppercase; color:var(--muted);
  border-bottom:2px solid var(--line2); padding:.62rem .8rem;
  background:var(--panel); white-space:nowrap;
}
th strong{color:var(--muted); font-weight:600}
td{padding:.58rem .8rem; border-bottom:1px solid var(--line); vertical-align:top}
tr:last-child td{border-bottom:none}
td:first-child{font-weight:600; color:var(--head)}

/* week-at-a-glance */
.weekly{min-width:940px; font-size:.86rem; line-height:1.5}
.weekly th:first-child, .weekly td:first-child{
  position:sticky; left:0; z-index:2; background:var(--card);
  border-right:1px solid var(--line2); text-align:center; min-width:5.2ch;
  font-family:ui-monospace,'SF Mono',Menlo,Consolas,monospace; font-size:.8rem; white-space:nowrap;
}
.weekly th:first-child{background:var(--panel)}
.weekly td:not(:first-child){min-width:24ch}
.weekly td:not(:first-child):has(strong){
  background:color-mix(in srgb, var(--brand) 7%, transparent);
}
.weekly td strong{color:var(--brand-ink)}

/* ── gate cards ── */
.gates{display:grid; gap:1.3rem; margin:1.8rem 0}
.gate{border:1px solid var(--line2); border-radius:12px; background:var(--card);
  overflow:hidden; box-shadow:var(--shadow)}
.gate-head{display:flex; gap:1rem; align-items:center; padding:.95rem 1.25rem;
  background:var(--panel); border-bottom:1px solid var(--line)}
.gate-no{
  flex:0 0 auto; width:2.5rem; height:2.5rem; display:grid; place-items:center;
  font-family:ui-monospace,'SF Mono',Menlo,Consolas,monospace;
  font-size:1.25rem; font-weight:700; color:var(--brand-ink);
  background:color-mix(in srgb, var(--brand) 11%, transparent);
  border:1px solid color-mix(in srgb, var(--brand) 30%, transparent); border-radius:9px;
}
.gate-name{font-weight:650; font-size:1.04rem; letter-spacing:-.01em; color:var(--head); line-height:1.3}
.gate-sub{font-size:.8rem; color:var(--muted); margin-top:.15rem; line-height:1.45}
.gate-grid{display:grid; grid-template-columns:1fr 1fr}
.gate-cell{padding:.95rem 1.25rem; font-size:.9rem; line-height:1.6}
.gate-cell p{margin:0; max-width:none}
.gate-cell.fail{border-left:1px solid var(--line)}
.gate-cell.act{grid-column:1 / -1; border-top:1px solid var(--line)}
.gl{
  font-family:ui-monospace,'SF Mono',Menlo,Consolas,monospace;
  font-size:.66rem; font-weight:600; letter-spacing:.09em; text-transform:uppercase;
  color:var(--muted); margin-bottom:.4rem; display:flex; align-items:center; gap:.45em;
}
.gl::before{content:""; width:.5em; height:.5em; border-radius:2px; background:var(--muted)}
.gate-cell.pass .gl::before{background:var(--pass)}
.gate-cell.fail .gl::before{background:var(--fail)}
.gate-cell.act .gl::before{background:var(--warn)}
.gate-kill{display:flex; gap:.9em; align-items:baseline; padding:.75rem 1.25rem;
  background:var(--panel); border-top:1px solid var(--line); font-size:.86rem}
.gate-kill .gl{margin:0; flex:0 0 auto}
.gate-kill .gl::before{background:var(--head)}

/* ── diagrams ── */
/* Figures are baked to inline SVG at build time (see step 1 above), so the
   page renders offline with no mermaid engine and no artifact runtime.
   The SVG paints itself from the tokens, so it follows the page theme and the
   flip button for free. Each sits on a tinted panel with its label as a caption;
   on a narrow screen the canvas scrolls sideways inside the panel instead of
   shrinking the text. The .mermaid selectors stay only so an unbaked build
   still gets a card instead of naked code. */
figure.fig{display:block; margin:2rem 0; padding:1.1rem 1.1rem .95rem;
  background:var(--fig); border:1px solid var(--line); border-radius:14px}
figure.fig .fig-canvas{overflow-x:auto; overscroll-behavior-x:contain; border-radius:8px;
  scrollbar-width:thin}
figure.fig svg{display:block; margin:0 auto}
figure.fig figcaption{margin:.85rem .15rem 0; max-width:70ch; font-size:.84rem;
  line-height:1.55; color:var(--muted); text-wrap:pretty}
figure.fig figcaption b{color:var(--head); font-weight:650}
pre.mermaid, div.mermaid-diagram{
  display:flex; justify-content:center; overflow-x:auto; margin:1.9rem 0;
  padding:1.4rem; background:var(--card); border:1px solid var(--line2);
  border-radius:12px; box-shadow:var(--shadow);
}

/* ── gantt ── */
.gwrap{overflow-x:auto; margin:1.6rem 0 .4rem; border:1px solid var(--line2);
  border-radius:12px; background:var(--card); box-shadow:var(--shadow)}
.gantt{min-width:940px; font-size:.78rem; line-height:1.35}
.g-row{display:flex; border-top:1px solid var(--line)}
.g-row:first-child{border-top:none}
.g-label{flex:0 0 224px; width:224px; padding:5px 12px; border-right:1px solid var(--line2);
  display:flex; flex-direction:column; justify-content:center; color:var(--text);
  position:sticky; left:0; z-index:3; background:var(--card)}
.g-label b{font-weight:650; color:var(--head)}
.g-label small{color:var(--muted); font-size:.85em}
.g-track{position:relative; flex:1; min-height:34px;
  background-image:linear-gradient(to right, var(--line) 1px, transparent 1px);
  background-size:__WEEKCOL__ 100%}
.g-track::after{content:""; position:absolute; top:0; bottom:0; left:__TAILSTART__; right:0;
  background:color-mix(in srgb, var(--panel) 72%, transparent);
  border-left:2px solid var(--line2); pointer-events:none}
.g-bar{position:absolute; z-index:1; top:6px; bottom:6px; border-radius:6px; color:#fff;
  font-weight:600; font-size:.68rem; display:flex; align-items:center; padding:0 8px;
  white-space:nowrap; overflow:hidden; text-overflow:ellipsis}
.g-bar.p{background:var(--bp)} .g-bar.a{background:var(--ba)}
.g-bar.d{background:var(--bd)} .g-bar.c{background:var(--bc)}
.g-bar.risk{background:transparent; border:2px dashed var(--bp); color:var(--sp); font-weight:650}
.g-phases .g-track{min-height:0; background:var(--panel)}
.g-band{position:absolute; top:0; bottom:0; display:flex; align-items:center; justify-content:center;
  font-family:ui-monospace,'SF Mono',Menlo,Consolas,monospace; font-size:.62rem; font-weight:600;
  letter-spacing:.07em; text-transform:uppercase; color:var(--muted);
  border-left:1px solid var(--line2); padding:4px 6px; overflow:hidden; white-space:nowrap}
.g-band:first-child{border-left:none}
.g-phases .g-label{background:var(--panel)}
.g-head .g-track{display:flex; background-image:none; background:var(--panel); min-height:0}
.g-head .g-label{background:var(--panel); font-family:ui-monospace,'SF Mono',Menlo,Consolas,monospace;
  font-size:.66rem; font-weight:600; letter-spacing:.08em; text-transform:uppercase; color:var(--muted)}
.g-head .g-track span{width:__WEEKCOL__; text-align:center; padding:5px 0;
  font-family:ui-monospace,'SF Mono',Menlo,Consolas,monospace; font-size:.7rem; font-weight:600; color:var(--muted)}
.g-head .g-track span.mo{width:__TAILW__; border-left:2px solid var(--line2)}
.g-gaterow .g-track{min-height:46px}
.g-gaterow .g-label{font-weight:650; color:var(--head)}
.g-gate{position:absolute; top:8px; width:0}
.g-gate i{position:absolute; left:-5px; top:0; width:10px; height:10px; background:var(--brand);
  border:1.5px solid var(--brand-ink); transform:rotate(45deg); border-radius:2px}
.g-gate em{position:absolute; top:16px; left:-45px; width:90px; text-align:center; font-style:normal;
  font-family:ui-monospace,'SF Mono',Menlo,Consolas,monospace; font-size:.62rem; font-weight:600; color:var(--brand-ink)}
.g-gate.edge-l em{left:-4px; text-align:left}
.g-sec{padding:4px 12px; font-family:ui-monospace,'SF Mono',Menlo,Consolas,monospace;
  font-size:.64rem; font-weight:600; letter-spacing:.09em; text-transform:uppercase;
  border-top:1px solid var(--line); background:var(--panel)}
.g-sec .st{position:sticky; left:12px; display:inline-block}
.g-sec.p{color:var(--sp)} .g-sec.a{color:var(--sa)} .g-sec.d{color:var(--sd)} .g-sec.c{color:var(--sc)}
.g-legend{display:flex; flex-wrap:wrap; gap:1rem; align-items:center; font-size:.75rem;
  color:var(--muted); margin:0 0 1.4rem}
.g-legend span{display:flex; align-items:center; gap:.4em}
.g-legend .chip{display:inline-block; width:20px; height:10px; border-radius:4px}
.g-legend .chip.p{background:var(--bp)} .g-legend .chip.a{background:var(--ba)}
.g-legend .chip.d{background:var(--bd)} .g-legend .chip.c{background:var(--bc)}
.g-legend .chip.risk{background:transparent; border:2px dashed var(--bp)}
.g-legend .dia{display:inline-block; width:9px; height:9px; background:var(--brand);
  border:1.5px solid var(--brand-ink); transform:rotate(45deg); border-radius:2px}

/* ── artwork ── */
figure.art{margin:2.4rem 0 0; border:1px solid var(--line2); border-radius:14px;
  overflow:hidden; background:#F7F7F9; box-shadow:var(--shadow)}
figure.art img{display:block; width:100%; height:auto}

/* ── theme flip ── */
#themeflip{position:fixed; top:14px; right:18px; z-index:50; width:36px; height:36px;
  display:grid; place-items:center; border-radius:50%; border:1px solid var(--line2);
  background:var(--card); color:var(--head); font-size:15px; line-height:1;
  cursor:pointer; box-shadow:var(--shadow)}
#themeflip:hover{background:var(--panel)}

/* ── mobile contents ── */
.toc-mobile{display:none}
:focus-visible{outline:none; box-shadow:0 0 0 3px color-mix(in srgb, var(--link) 30%, transparent); border-radius:4px}
@media (max-width:960px){
  nav.side{display:none}
  #themeflip{top:10px; right:12px; width:32px; height:32px; font-size:14px}
  main{padding:22px 56px 70px 20px}
  .toc-mobile{display:block; margin:0 0 1.2rem; border:1px solid var(--line);
    border-radius:10px; background:var(--card); padding:.4rem .9rem; font-size:.85rem}
  .toc-mobile summary{cursor:pointer; font-weight:650; color:var(--head); padding:.3rem 0}
  .toc-mobile ul{list-style:none; padding:0}
  .toc-mobile a{display:block; padding:3px 0; color:var(--muted); text-decoration:none}
  .gate-grid{grid-template-columns:1fr}
  .gate-cell.fail{border-left:none; border-top:1px solid var(--line)}
  h1{font-size:1.75rem}
  .ch-title{font-size:1.35rem}
  .tldr{padding:1.35rem 1.1rem 1.1rem}
  .tldr .ch-title{font-size:1.25rem}
}
/* ── Grid family (IBM Carbon derived): square, light display, tiles ── */
/* Structure for the plan, matching the PRD shell's Grid rules. Tokens come from
   the families block above; with data-family="project-f" none of this applies. */
:root[data-family="grid"] .stat, :root[data-family="grid"] .tbl, :root[data-family="grid"] .gate,
:root[data-family="grid"] figure.fig, :root[data-family="grid"] figure.fig .fig-canvas, :root[data-family="grid"] .tldr,
:root[data-family="grid"] code, :root[data-family="grid"] blockquote, :root[data-family="grid"] .gate-no,
:root[data-family="grid"] .toc-mobile, :root[data-family="grid"] nav.side a, :root[data-family="grid"] .ws,
:root[data-family="grid"] #themeflip, :root[data-family="grid"] .gwrap, :root[data-family="grid"] .g-bar,
:root[data-family="grid"] figure.art, :root[data-family="grid"] .g-legend .chip, :root[data-family="grid"] pre.mermaid{border-radius:0}
:root[data-family="grid"] .ch-kicker, :root[data-family="grid"] .nav-group, :root[data-family="grid"] .nav-brand .nb-d{
  font-family:inherit; text-transform:none; letter-spacing:0; font-weight:400}
:root[data-family="grid"] .ch-kicker{font-size:.85rem}
:root[data-family="grid"] .ch-title{font-family:var(--font-display); font-weight:300; font-size:2rem; letter-spacing:-.015em}
:root[data-family="grid"] .tldr .ch-title{font-size:1.6rem}
:root[data-family="grid"] h2{border-top:1px solid var(--line2)}
:root[data-family="grid"] .tldr h2{border-top:none}
:root[data-family="grid"] .tldr{box-shadow:none; border-color:var(--line)}
:root[data-family="grid"] .tldr::before{height:4px; background:var(--brand)}
:root[data-family="grid"] .tbl, :root[data-family="grid"] .gate, :root[data-family="grid"] .gwrap, :root[data-family="grid"] figure.art{box-shadow:none}
:root[data-family="grid"] .gate-head, :root[data-family="grid"] .gate-kill{background:var(--panel)}
:root[data-family="grid"] figure.fig{border:0}
:root[data-family="grid"] nav.side a.on{background:var(--panel); color:var(--head)}
@media (max-width:960px){
  :root[data-family="grid"] .ch-title{font-size:1.5rem}
}
"""
CSS = (CSS.replace("__WEEKCOL__", f"{W:.4f}%")
          .replace("__TAILSTART__", f"{GHEAD:g}%")
          .replace("__TAILW__", f"{GTAIL:g}%"))

JS = """
(function(){
  var links = Array.prototype.slice.call(document.querySelectorAll("nav.side a[href^='#']"));
  var anchors = Array.prototype.slice.call(document.querySelectorAll("main a[id]"));
  if (!links.length || !anchors.length) return;
  function spy(){
    var cur = anchors[0];
    for (var i = 0; i < anchors.length; i++){
      if (anchors[i].getBoundingClientRect().top <= 130) cur = anchors[i]; else break;
    }
    links.forEach(function(l){
      l.classList.toggle("on", l.getAttribute("href") === "#" + cur.id);
    });
  }
  var t = false;
  addEventListener("scroll", function(){
    if (t) return; t = true;
    requestAnimationFrame(function(){ spy(); t = false; });
  }, {passive:true});
  spy();

  var flip = document.createElement("button");
  flip.id = "themeflip"; flip.type = "button";
  flip.setAttribute("aria-label", "Switch between light and dark");
  flip.textContent = "\\u25D0";
  flip.addEventListener("click", function(){
    var root = document.documentElement;
    var t = root.getAttribute("data-theme");
    var dark = t ? t === "dark"
      : (window.matchMedia && matchMedia("(prefers-color-scheme: dark)").matches);
    var next = dark ? "light" : "dark";
    root.setAttribute("data-theme", next);
    root.style.colorScheme = next;
  });
  document.body.appendChild(flip);
})();
"""

toc_mobile = re.sub(r'<div class="nav-note">.*?</div>', '', toc, flags=re.S)

page = f"""<meta charset="utf-8">
<script>if(!document.documentElement.hasAttribute("data-family"))document.documentElement.setAttribute("data-family","{FAMILY}");</script>
<title>{TITLE}</title>
<style>{CSS}</style>
<div class="layout">
<nav class="side">
  <div class="nav-brand"><div class="nb-t">{NAV_BRAND}</div><div class="nb-d">{NAV_SUBTITLE}</div></div>
  {toc}
</nav>
<main>
<details class="toc-mobile"><summary>Contents</summary>{toc_mobile}</details>
{body}
</main>
</div>
<script>{JS}</script>
"""

# The artifact wants a body fragment (the platform supplies doctype and head).
# A file that gets emailed wants a whole document: without a doctype Chrome
# drops into quirks mode, and without a viewport tag phones render it tiny.
share = (f'<!doctype html>\n<html lang="en" data-family="{FAMILY}">\n<head>\n<meta charset="utf-8">\n'
         '<meta name="viewport" content="width=device-width,initial-scale=1">\n'
         f'<title>{TITLE}</title>\n<style>{CSS}</style>\n</head>\n<body>\n'
         + page.split("</style>\n", 1)[1] + "\n</body>\n</html>\n")

for label, doc in (("artifact body", page), ("share copy", share)):
    for cp, name in ((0x2014, "em dash"), (0x2013, "en dash")):
        if chr(cp) in doc:
            i = doc.find(chr(cp))
            die(f"{name} in {label} at offset {i}: "
                f"...{doc[max(0,i-60):i+60]!r}...")

open(f"{DIR}/{SLUG}.html", "w").write(page)
open(f"{DIR}/{SLUG}-share.html", "w").write(share)
print(f"OK {len(page)} chars -> {SLUG}.html")
print(f"OK {len(share)} chars -> {SLUG}-share.html")
