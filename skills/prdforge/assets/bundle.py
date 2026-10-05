#!/usr/bin/env python3
"""Bundle every prdforge output for one slug into a single tabbed page.

Usage:
  bundle.py --out-dir <outDir> --slug <slug> [--template <prd-template.html>]
Writes <outDir>/<slug>-bundle.html and prints one JSON line:
  {bundlePath, tabs, bytes, checks}. Exit 1 if a check fails or there is nothing to bundle.
Gate: when a PRD is present, <slug>-prd.json must exist and pass render_prd's diagram check
(and the PRD page must carry baked SVG, not raw mermaid), or nothing is written and it exits 1.
The external-reference check only flags things a page would load (src, srcset, poster,
action, <link href>, @import, url()); anchor links and text are fine.

Tabs, in order, each only when its file exists:
  PRD      <slug>-prd.html
  Plan     <slug>-plan-share.html, else <slug>-plan.html (a fragment, wrapped here)
  Prompt   <slug>-prompt.md, rendered as readable, copyable text
  Handoff  <slug>-handoff.md

Mechanism: every document is a whole page with its own CSS, scripts and scrollspy, so
each one runs in its own iframe (srcdoc) under a sticky tab bar and none of them can
restyle another. Sources sit in inert JSON script blocks and a frame is only created the
first time its tab opens. A small bridge injected into each document:
  - sets <base href="about:srcdoc">, without which an in-page link such as #tldr resolves
    against the bundle's own URL and loads the whole bundle inside the frame;
  - takes the theme from the frame name at first paint (no flash) and from postMessage
    after that, so one toggle in the bar drives every document;
  - hides the document's own theme button, since the bar owns the theme.
The tab lives in the URL hash (#prd, #plan, #prompt, #handoff) so a link can open a tab.
No network, no storage it depends on (the theme choice is remembered when storage works),
and nothing that needs same-origin access, so it runs offline and inside a sandboxed
claude.ai Artifact frame.
"""
import argparse, html, json, os, re, sys

E = html.escape
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from render_prd import check_diagrams, external_refs  # noqa: E402  one definition, shared with the render

def family(template):
    """The theme family the PRD shell defaults to (data-family on its <html>)."""
    with open(template, encoding="utf-8") as f:
        m = re.search(r'<html[^>]*\bdata-family="([a-z-]+)"', f.read())
    return m.group(1) if m else "project-f"


def tokens(template):
    """The project-f token blocks (light, dark by media, both data-theme overrides), read from
    the PRD shell so the bundle can never drift from it."""
    with open(template, encoding="utf-8") as f:
        css = f.read()
    start = css.index(":root{")
    return css[start:css.index("*{box-sizing", start)].strip()


# ---------------------------------------------------------------- markdown (small, deterministic)
def inline(t):
    codes = []

    def keep(m):
        codes.append(f"<code>{E(m.group(1))}</code>")
        return f"\x00{len(codes) - 1}\x00"
    t = re.sub(r"`([^`]+)`", keep, t)
    t = E(t, quote=False)
    t = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", t)
    t = re.sub(r"(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])", r"<em>\1</em>", t)
    t = re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)",
               lambda m: f'<a href="{m.group(2).replace(chr(34), "%22")}" target="_blank" rel="noopener">{m.group(1)}</a>'
               if not re.match(r"\s*javascript:", m.group(2), re.I) else m.group(1), t)
    t = re.sub(r"^([A-Z][A-Za-z /-]{1,30}):(\s)", r'<strong class="lead">\1</strong>\2', t)
    return re.sub(r"\x00(\d+)\x00", lambda m: codes[int(m.group(1))], t)


def md_to_html(md):
    lines, out, i = md.replace("\r\n", "\n").split("\n"), [], 0
    para = []

    def flush():
        if para:
            out.append(f"<p>{inline(' '.join(s.strip() for s in para))}</p>")
            para.clear()
    while i < len(lines):
        ln = lines[i]
        if ln.strip().startswith("```"):
            flush()
            body, i = [], i + 1
            while i < len(lines) and not lines[i].strip().startswith("```"):
                body.append(lines[i])
                i += 1
            out.append(f"<pre><code>{E(chr(10).join(body))}</code></pre>")
            i += 1
            continue
        h = re.match(r"^(#{1,6})\s+(.*)$", ln)
        if h:
            flush()
            n = min(len(h.group(1)) + 1, 4)
            out.append(f"<h{n}>{inline(h.group(2))}</h{n}>")
        elif re.match(r"^\s*(-{3,}|\*{3,})\s*$", ln):
            flush()
            out.append("<hr>")
        elif ln.strip().startswith("|") and i + 1 < len(lines) and re.match(r"^\s*\|?\s*:?-{3,}", lines[i + 1]):
            flush()
            cells = lambda s: [c.strip() for c in s.strip().strip("|").split("|")]
            head, rows, i = cells(ln), [], i + 2
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append(cells(lines[i]))
                i += 1
            out.append('<div class="tbl"><table><thead><tr>' + "".join(f"<th>{inline(c)}</th>" for c in head) +
                       "</tr></thead><tbody>" + "".join("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>"
                                                        for r in rows) + "</tbody></table></div>")
            continue
        elif re.match(r"^\s*([-*]|\d+[.)])\s+", ln):
            flush()
            ordered = bool(re.match(r"^\s*\d+[.)]", ln))
            items = []
            while i < len(lines) and (re.match(r"^\s*([-*]|\d+[.)])\s+", lines[i]) or
                                      (lines[i].startswith("  ") and lines[i].strip() and items)):
                m = re.match(r"^\s*(?:[-*]|\d+[.)])\s+(.*)$", lines[i])
                if m:
                    items.append(m.group(1))
                else:
                    items[-1] += " " + lines[i].strip()
                i += 1
            lis = []
            for it in items:
                box = re.match(r"^\[( |x|X)\]\s+(.*)$", it)
                if box:
                    chk = " checked" if box.group(1).lower() == "x" else ""
                    lis.append(f'<li class="task"><input type="checkbox" disabled{chk} aria-hidden="true">'
                               f"<span>{inline(box.group(2))}</span></li>")
                else:
                    lis.append(f"<li>{inline(it)}</li>")
            tag = "ol" if ordered else "ul"
            out.append(f"<{tag}>{''.join(lis)}</{tag}>")
            continue
        elif ln.startswith(">"):
            flush()
            quote = []
            while i < len(lines) and lines[i].startswith(">"):
                quote.append(lines[i].lstrip(">").strip())
                i += 1
            out.append(f"<blockquote><p>{inline(' '.join(quote))}</p></blockquote>")
            continue
        elif not ln.strip():
            flush()
        else:
            para.append(ln)
        i += 1
    flush()
    return "\n".join(out)


TEXT_DOC_CSS = """
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);font:16px/1.68 system-ui,-apple-system,'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif;
  -webkit-font-smoothing:antialiased}
main{max-width:52rem;margin:0 auto;padding:44px 24px 96px}
.kicker{font:600 .7rem/1.4 ui-monospace,'SF Mono',Menlo,Consolas,monospace;letter-spacing:.09em;text-transform:uppercase;color:var(--brand-ink);margin:0 0 .6rem}
h1{font-size:clamp(1.8rem,3vw,2.3rem);line-height:1.1;letter-spacing:-.025em;color:var(--head);margin:0 0 .6rem;text-wrap:balance}
.sub{color:var(--muted);margin:0 0 1.6rem;max-width:44em}
.bar{display:flex;flex-wrap:wrap;gap:.6rem;align-items:center;margin:0 0 1.4rem}
.copy{font:inherit;font-size:.85rem;font-weight:600;cursor:pointer;color:var(--head);background:var(--card);
  border:1px solid var(--line2);border-radius:8px;padding:.4rem .9rem;box-shadow:var(--shadow)}
.copy:hover{border-color:var(--brand)}
.status{font-size:.82rem;color:var(--muted)}
article{background:var(--card);border:1px solid var(--line2);border-radius:14px;padding:1.4rem 1.6rem;box-shadow:var(--shadow)}
article p,article li{overflow-wrap:anywhere}
article p{margin:.2rem 0 1rem}
article p:last-child{margin-bottom:0}
strong{color:var(--head);font-weight:650}
strong.lead{display:block;font:600 .7rem/1.4 ui-monospace,'SF Mono',Menlo,Consolas,monospace;letter-spacing:.09em;
  text-transform:uppercase;color:var(--brand-ink);margin:0 0 .25rem}
h2,h3,h4{color:var(--head);letter-spacing:-.012em;line-height:1.3;margin:1.8rem 0 .6rem;text-wrap:balance}
h2{font-size:1.3rem} h3{font-size:1.1rem} h4{font-size:1rem}
article>h2:first-child,article>h3:first-child{margin-top:0}
code{font:.86em ui-monospace,'SF Mono',Menlo,Consolas,monospace;background:var(--panel);border:1px solid var(--line);
  padding:.06em .34em;border-radius:5px;color:var(--head)}
pre{background:var(--panel);border:1px solid var(--line2);border-radius:10px;padding:1rem 1.1rem;overflow-x:auto}
pre code{background:none;border:0;padding:0;font-size:13px;line-height:1.6}
li.task{list-style:none;display:flex;gap:.55rem;align-items:flex-start;margin-left:-1.3rem}
li.task input{margin-top:.4rem;accent-color:var(--brand)}
blockquote{margin:1rem 0;padding:.8rem 1.1rem;background:var(--panel);border:1px solid var(--line);border-radius:10px}
.tbl{overflow-x:auto;margin:1rem 0;border:1px solid var(--line);border-radius:10px}
table{border-collapse:collapse;width:100%;font-size:.9rem}
th{text-align:left;font:600 .68rem ui-monospace,'SF Mono',Menlo,Consolas,monospace;letter-spacing:.07em;text-transform:uppercase;
  color:var(--muted);background:var(--panel);border-bottom:2px solid var(--line2);padding:.55rem .75rem}
td{padding:.5rem .75rem;border-bottom:1px solid var(--line);vertical-align:top}
a{color:var(--link)}
:focus-visible{outline:none;box-shadow:0 0 0 3px color-mix(in srgb,var(--link) 30%,transparent);border-radius:6px}
hr{border:none;border-top:1px solid var(--line);margin:2rem 0}
@media (max-width:640px){main{padding:24px 16px 72px} article{padding:1.1rem 1rem}}
[data-family="almanac"] body{font-size:17px}
[data-family="almanac"] h1,[data-family="almanac"] h2,[data-family="almanac"] h3{font-family:var(--font-display);font-weight:500}
[data-family="almanac"] .kicker,[data-family="almanac"] strong.lead{font-family:inherit;text-transform:none;letter-spacing:0;font-size:.9rem}
[data-family="almanac"] article{box-shadow:none;border-radius:4px;border-color:var(--line)}
[data-family="console"] body{font-size:15px}
[data-family="console"] main{max-width:60rem;padding-top:28px}
[data-family="console"] h1{font-size:1.75rem;font-weight:600}
[data-family="console"] article{box-shadow:none;border-radius:8px;padding:1rem 1.2rem}
[data-family="grid"] h1{font-family:var(--font-display);font-weight:300;font-size:clamp(2rem,4vw,2.8rem)}
[data-family="grid"] .kicker,[data-family="grid"] strong.lead{font-family:inherit;text-transform:none;letter-spacing:0;font-size:.85rem;font-weight:400}
[data-family="grid"] article,[data-family="grid"] .copy,[data-family="grid"] pre,[data-family="grid"] code,[data-family="grid"] .tbl{border-radius:0;box-shadow:none}
[data-family="grid"] article{border:0;background:var(--panel)}
"""

TEXT_DOC_JS = """
(function(){
  var btn = document.getElementById("copy"), st = document.getElementById("copy-status");
  var src = document.getElementById("raw");
  function say(m){ st.textContent = m; setTimeout(function(){ st.textContent = ""; }, 1800); }
  function fallback(txt){
    var ta = document.createElement("textarea"); ta.value = txt; ta.setAttribute("readonly", "");
    ta.style.position = "fixed"; ta.style.opacity = "0"; document.body.appendChild(ta); ta.select();
    var ok = false; try { ok = document.execCommand("copy"); } catch (e) {}
    document.body.removeChild(ta); say(ok ? "Copied" : "Copy blocked here: select the text and copy it by hand");
  }
  btn.addEventListener("click", function(){
    var txt = src.textContent;
    if (navigator.clipboard && navigator.clipboard.writeText)
      navigator.clipboard.writeText(txt).then(function(){ say("Copied"); }, function(){ fallback(txt); });
    else fallback(txt);
  });
})();
"""


def text_doc(tokens_css, fam, kicker, title, sub, md, copy_label):
    raw = E(md, quote=False)
    return (f'<!doctype html><html lang="en" data-family="{E(fam)}"><head><meta charset="utf-8">'
            f'<meta name="viewport" content="width=device-width,initial-scale=1"><title>{E(title)}</title>'
            f"<style>{tokens_css}\n{TEXT_DOC_CSS}</style></head><body><main>"
            f'<p class="kicker">{E(kicker)}</p><h1>{E(title)}</h1><p class="sub">{E(sub)}</p>'
            f'<div class="bar"><button class="copy" id="copy" type="button">{E(copy_label)}</button>'
            f'<span class="status" id="copy-status" role="status" aria-live="polite"></span></div>'
            f"<article>{md_to_html(md)}</article>"
            f'<pre id="raw" hidden>{raw}</pre></main><script>{TEXT_DOC_JS}</script></body></html>')


# ---------------------------------------------------------------- bridge injected into every document
BRIDGE = """<base href="about:srcdoc"><style>#themeflip{display:none!important}</style><script>
(function(){
  var r = document.documentElement, last = null;
  function set(t){ if (t !== "light" && t !== "dark") return; last = t; r.setAttribute("data-theme", t); r.style.colorScheme = t; }
  var m = /^prdforge-theme:(light|dark)$/.exec(window.name || ""); if (m) set(m[1]);
  addEventListener("message", function(e){
    if (e.source !== window.parent || !e.data || typeof e.data !== "object") return;
    if (e.data.prdforgeTheme) set(e.data.prdforgeTheme);
  });
})();
</script>"""


def with_bridge(doc):
    if not re.search(r"<html[\s>]", doc, re.I):  # plan.html is a fragment: give it a document
        doc = ('<!doctype html><html lang="en"><head><meta charset="utf-8">'
               '<meta name="viewport" content="width=device-width,initial-scale=1"></head>'
               f"<body>{doc}</body></html>")
    m = re.search(r"<head[^>]*>", doc, re.I)
    if m:
        return doc[:m.end()] + BRIDGE + doc[m.end():]
    m = re.search(r"<html[^>]*>", doc, re.I)
    return doc[:m.end()] + "<head>" + BRIDGE + "</head>" + doc[m.end():]


def title_of(html_doc):
    m = re.search(r"<title>(.*?)</title>", html_doc or "", re.S | re.I)
    return html.unescape(m.group(1)).split(" · ")[0].strip() if m else ""


# ---------------------------------------------------------------- shell
SHELL_CSS = """
*{box-sizing:border-box}
html,body{height:100%}
body{margin:0;background:var(--bg);color:var(--text);display:flex;flex-direction:column;height:100vh;height:100dvh;overflow:hidden;
  font:15px/1.5 system-ui,-apple-system,'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif;-webkit-font-smoothing:antialiased}
.tabsbar{position:sticky;top:env(safe-area-inset-top,0px);z-index:20;flex:0 0 auto;background:var(--bg);
  border-bottom:1px solid var(--line2);box-shadow:0 1px 0 var(--line)}
.tabsbar .in{display:flex;align-items:center;gap:18px;max-width:1800px;margin:0 auto;padding:10px 20px}
.brand{min-width:0;flex:0 1 auto;display:flex;flex-direction:column}
.brand .k{font:600 .64rem/1.3 ui-monospace,'SF Mono',Menlo,Consolas,monospace;letter-spacing:.1em;text-transform:uppercase;color:var(--muted)}
.brand .t{font-weight:650;font-size:.95rem;color:var(--head);letter-spacing:-.01em;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:28ch}
.tabs{display:flex;gap:4px;min-width:0;flex:1 1 auto;overflow-x:auto;scrollbar-width:none;padding:2px}
.tabs::-webkit-scrollbar{display:none}
.tab{flex:0 0 auto;display:flex;flex-direction:column;align-items:flex-start;gap:1px;text-align:left;cursor:pointer;
  font:inherit;color:var(--muted);background:transparent;border:1px solid transparent;border-radius:9px;padding:6px 12px 7px;
  position:relative;transition:background 140ms cubic-bezier(.23,1,.32,1),color 140ms cubic-bezier(.23,1,.32,1),border-color 140ms}
.tab .l{display:flex;align-items:baseline;gap:6px;font-weight:650;font-size:.88rem;color:var(--head);white-space:nowrap}
.tab .n{font:600 .7rem ui-monospace,'SF Mono',Menlo,Consolas,monospace;color:var(--muted);font-variant-numeric:tabular-nums}
.tab .d{font-size:.72rem;line-height:1.35;color:var(--muted);white-space:nowrap;max-width:30ch;overflow:hidden;text-overflow:ellipsis}
.tab:hover{background:var(--panel)}
.tab[aria-selected="true"]{background:color-mix(in srgb,var(--brand) 9%,transparent);border-color:color-mix(in srgb,var(--brand) 30%,transparent)}
.tab[aria-selected="true"] .l,.tab[aria-selected="true"] .n{color:var(--brand-ink)}
.tab:focus-visible,.flip:focus-visible{outline:none;box-shadow:0 0 0 3px color-mix(in srgb,var(--link) 35%,transparent)}
.flip{flex:0 0 auto;width:34px;height:34px;display:grid;place-items:center;border-radius:50%;border:1px solid var(--line2);
  background:var(--card);color:var(--head);font-size:15px;line-height:1;cursor:pointer;box-shadow:var(--shadow)}
.flip:hover{background:var(--panel)}
.panes{flex:1 1 auto;min-height:0;position:relative}
.pane{position:absolute;inset:0}
.pane[hidden]{display:none}
.pane iframe{display:block;width:100%;height:100%;border:0;background:var(--bg)}
.sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap}
@media (max-width:760px){
  .tabsbar .in{flex-wrap:wrap;gap:6px 10px;padding:8px 12px}
  .brand{flex:1 1 0}
  .brand .t{max-width:none}
  .tabs{order:3;flex:1 0 100%;margin:0 -2px}
  .tab{padding:5px 10px}
  .tab .d{display:none}
}
@media (prefers-reduced-motion: reduce){ .tab{transition:none} }
[data-family="almanac"] .brand .t{font-family:var(--font-display);font-weight:500;font-size:1.08rem}
[data-family="almanac"] .brand .k{font-family:inherit;text-transform:none;letter-spacing:0;font-size:.72rem}
[data-family="almanac"] .tabsbar{box-shadow:none}
[data-family="almanac"] .tab{border-radius:0;border:0;padding:8px 14px 9px}
[data-family="almanac"] .tab .n,[data-family="console"] .tab .n,[data-family="grid"] .tab .n{display:none}
[data-family="almanac"] .tab:hover{background:none}
[data-family="almanac"] .tab[aria-selected="true"]{background:none;box-shadow:inset 0 -2px 0 var(--brand)}
[data-family="almanac"] .tab .l{font-family:var(--font-display);font-weight:500;font-size:.98rem}
[data-family="console"] .tabsbar .in{padding:6px 16px;gap:14px}
[data-family="console"] .brand .k,[data-family="console"] .tab .d{display:none}
[data-family="console"] .brand .t{font-size:.86rem;font-weight:600}
[data-family="console"] .tab{padding:4px 10px;border-radius:6px}
[data-family="console"] .tab .l{font-size:.8rem;font-weight:600}
[data-family="console"] .tab[aria-selected="true"]{background:var(--panel);border-color:var(--line2)}
[data-family="console"] .flip{width:28px;height:28px;font-size:13px;box-shadow:none}
[data-family="grid"] .tabsbar{background:var(--panel);box-shadow:none}
[data-family="grid"] .tabsbar .in{padding:0 0 0 20px;align-items:stretch;gap:24px}
[data-family="grid"] .brand{justify-content:center}
[data-family="grid"] .brand .k{font-family:inherit;text-transform:none;letter-spacing:0;font-size:.75rem}
[data-family="grid"] .tabs{gap:0;padding:0}
[data-family="grid"] .tab{border-radius:0;border:0;padding:12px 18px}
[data-family="grid"] .tab:hover{background:var(--line)}
[data-family="grid"] .tab[aria-selected="true"]{background:var(--bg);box-shadow:inset 0 2px 0 var(--brand)}
[data-family="grid"] .flip{border-radius:0;align-self:center;margin-right:16px;box-shadow:none}
@media (max-width:760px){
  [data-family="grid"] .tabsbar .in{padding:8px 12px 0;gap:6px 10px}
  [data-family="grid"] .flip{margin-right:0}
  [data-family="grid"] .tab{padding:9px 14px}
}
"""

SHELL_JS = """
(function(){
  var root = document.documentElement, KEY = "prdforge:bundle:theme", LS = null;
  try { LS = window.localStorage; } catch (e) {}
  var tabs = [].slice.call(document.querySelectorAll('[role="tab"]'));
  var ids = tabs.map(function(t){ return t.getAttribute("data-doc"); });
  var theme = null;
  try { theme = LS && LS.getItem(KEY); } catch (e) {}
  if (theme !== "light" && theme !== "dark") theme = null;
  function effective(){ return theme || (window.matchMedia && matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"); }
  function frames(){ return [].slice.call(document.querySelectorAll(".pane iframe")); }
  function applyTheme(){
    if (theme) { root.setAttribute("data-theme", theme); root.style.colorScheme = theme; }
    frames().forEach(function(f){
      f.name = theme ? "prdforge-theme:" + theme : "";
      if (theme && f.contentWindow) f.contentWindow.postMessage({prdforgeTheme: theme}, "*");
    });
  }
  function mount(id){
    var pane = document.getElementById("p-" + id);
    if (!pane || pane.querySelector("iframe")) return;
    var src = document.getElementById("d-" + id);
    var f = document.createElement("iframe");
    f.title = pane.getAttribute("data-title");
    f.name = theme ? "prdforge-theme:" + theme : "";
    f.srcdoc = JSON.parse(src.textContent);
    pane.appendChild(f);
  }
  function select(id, focus){
    if (ids.indexOf(id) < 0) id = ids[0];
    tabs.forEach(function(t){
      var on = t.getAttribute("data-doc") === id;
      t.setAttribute("aria-selected", on ? "true" : "false");
      t.tabIndex = on ? 0 : -1;
      document.getElementById("p-" + t.getAttribute("data-doc")).hidden = !on;
      if (on) { if (focus) t.focus(); t.scrollIntoView({block: "nearest", inline: "nearest"}); }
    });
    mount(id);
    document.title = document.getElementById("t-" + id).getAttribute("data-name") + " · " + document.body.getAttribute("data-title");
    if (location.hash.slice(1) !== id) {
      try { history.replaceState(null, "", "#" + id); } catch (e) { try { location.hash = id; } catch (e2) {} }
    }
  }
  tabs.forEach(function(t, i){
    t.addEventListener("click", function(){ select(t.getAttribute("data-doc"), false); });
    t.addEventListener("keydown", function(e){
      var k = e.key, j = null;
      if (k === "ArrowRight") j = (i + 1) % tabs.length;
      else if (k === "ArrowLeft") j = (i - 1 + tabs.length) % tabs.length;
      else if (k === "Home") j = 0;
      else if (k === "End") j = tabs.length - 1;
      if (j === null) return;
      e.preventDefault(); select(tabs[j].getAttribute("data-doc"), true);
    });
  });
  addEventListener("hashchange", function(){ select(location.hash.slice(1), false); });
  document.getElementById("flip").addEventListener("click", function(){
    theme = effective() === "dark" ? "light" : "dark";
    try { LS && LS.setItem(KEY, theme); } catch (e) {}
    applyTheme();
  });
  applyTheme();
  select(location.hash.slice(1), false);
})();
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--slug", required=True)
    ap.add_argument("--template", default=os.path.join(HERE, "prd-template.html"))
    a = ap.parse_args()
    base = os.path.join(a.out_dir, a.slug)

    def read(suffix):
        p = base + suffix
        if not os.path.exists(p):
            return None
        with open(p, encoding="utf-8") as f:
            return f.read()

    try:
        tok = tokens(a.template)
        fam = family(a.template)
    except (OSError, ValueError) as e:
        print(json.dumps({"bundlePath": None, "tabs": [], "checks": [f"cannot read theme tokens from {a.template}: {e}"]}))
        sys.exit(1)
    prd_json, prd_json_ok = {}, False
    try:
        raw = read("-prd.json")
        prd_json, prd_json_ok = (json.loads(raw), True) if raw else ({}, False)
    except ValueError:
        pass
    prd = read("-prd.html")
    if prd:  # never bundle (and so never publish) a PRD that failed the diagrams gate
        gate = check_diagrams(prd_json, prd) if prd_json_ok else [f"{a.slug}-prd.json missing or unreadable, cannot verify diagrams"]
        if gate:
            print(json.dumps({"bundlePath": None, "tabs": [], "checks": gate}))
            sys.exit(1)
    title = prd_json.get("title") or title_of(prd) or a.slug
    docs = []  # (id, name, description, html)
    if prd:
        fr = len((prd_json.get("requirements") or {}).get("functional") or [])
        oq = len(prd_json.get("openQuestions") or [])
        desc = f"{fr} requirements, {oq} open questions" if prd_json else "Requirements and acceptance criteria"
        docs.append(("prd", "PRD", desc, prd))
    plan = read("-plan-share.html") or read("-plan.html")
    if plan:
        docs.append(("plan", "Plan", "Delivery plan, diagrams and gates", plan))
    prompt = read("-prompt.md")
    if prompt:
        docs.append(("prompt", "Prompt", "Paste-ready implementation prompt",
                     text_doc(tok, fam, "Implementation prompt", title,
                              "Paste this into a fresh coding session. It carries the context, the objective, "
                              "what must not change and how to prove it works.", prompt, "Copy prompt")))
    handoff = read("-handoff.md")
    if handoff:
        docs.append(("handoff", "Handoff", "Task-by-task plan for a cheaper model",
                     text_doc(tok, fam, "Execution handoff", title,
                              "Tasks sized for one session each, with a done check a model can verify alone.",
                              handoff, "Copy handoff")))
    if not docs:
        print(json.dumps({"bundlePath": None, "tabs": [], "checks": [f"no prdforge outputs for {a.slug} in {a.out_dir}"]}))
        sys.exit(1)

    problems = []
    for id_, name, _, h in docs:
        ext = external_refs(h)
        if ext:
            problems.append(f"{name}: external reference {ext[0]}")

    tab_html, panes, data = [], [], []
    for n, (id_, name, desc, h) in enumerate(docs, 1):
        tab_html.append(f'<button type="button" class="tab" role="tab" id="t-{id_}" data-doc="{id_}" data-name="{E(name)}" '
                        f'aria-controls="p-{id_}" aria-selected="false" tabindex="-1">'
                        f'<span class="l"><span class="n">{n:02d}</span>{E(name)}</span><span class="d">{E(desc)}</span></button>')
        panes.append(f'<section class="pane" role="tabpanel" id="p-{id_}" aria-labelledby="t-{id_}" '
                     f'data-title="{E(name)}: {E(title)}" hidden></section>')
        # inert JSON: every "<" escaped so no sequence inside can close or confuse the script element
        blob = json.dumps(with_bridge(h), ensure_ascii=False).replace("<", "\\u003c")
        data.append(f'<script type="application/json" id="d-{id_}">{blob}</script>')

    page = (f'<!doctype html>\n<html lang="en" data-family="{E(fam)}"><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">'
            f"<title>{E(title)} · prdforge</title><style>{tok}\n{SHELL_CSS}</style></head>"
            f'<body data-title="{E(title)}"><header class="tabsbar"><div class="in">'
            f'<div class="brand"><span class="k">prdforge</span><span class="t" title="{E(title)}">{E(title)}</span></div>'
            f'<div class="tabs" role="tablist" aria-label="Documents">{"".join(tab_html)}</div>'
            '<button type="button" class="flip" id="flip" aria-label="Switch between light and dark">&#9680;</button>'
            f'</div></header><main class="panes">{"".join(panes)}</main>'
            f'{"".join(data)}<script>{SHELL_JS}</script></body></html>\n')
    shell_only = re.sub(r'<script type="application/json"[^>]*>.*?</script>', "", page, flags=re.S)
    if external_refs(shell_only):
        problems.append("bundle shell has an external reference")
    for cp, nm in ((0x2014, "em dash"), (0x2013, "en dash")):
        if chr(cp) in shell_only:
            problems.append(f"{nm} in bundle shell")
    out = base + "-bundle.html"
    with open(out, "w", encoding="utf-8") as f:
        f.write(page)
    print(json.dumps({"bundlePath": out, "tabs": [d[1] for d in docs], "bytes": len(page.encode("utf-8")),
                      "checks": problems or "ok"}))
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
