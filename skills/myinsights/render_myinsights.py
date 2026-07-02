#!/usr/bin/env python3
"""render_myinsights.py <quant.json> <narrative.json> <timestamp> <out.html>
Merged, all-logins Claude Code insights report. Quantitative rollups (full corpus, n=sessions) +
qualitative narrative at /insights depth (sampled facets, n=facets). Body-only self-contained HTML.
Honesty-first: full-corpus and sampled figures are badged and never mixed.
Design system: Linear (~/Repos/design-ai/design-md/linear/DESIGN.md) — near-black layered
surfaces, indigo accents, compact type, fine borders. All CSS inline, no webfonts/CDN (CSP-safe).
Includes a deterministic ranked Scorecard: 9 factors scored 0-100 by disclosed formulas over
quant.json, graded, ranked, and combined into a weighted composite. No LLM-invented numbers.
Narrative schema: headline, project_areas[{name,session_count,description}],
interaction_style{narrative,key_pattern}, what_works{intro,impressive_workflows[{title,description}]},
friction{intro,categories[{category,description,examples[]}]},
suggestions{claude_md_additions[{addition,why,prompt_scaffold}],features_to_try[{feature,one_liner,why_for_you,example_code}],usage_patterns[{title,suggestion,detail,copyable_prompt}]},
on_the_horizon{intro,opportunities[{title,whats_possible,how_to_try,copyable_prompt}]},
fun_ending{headline,detail}, at_a_glance{whats_working,whats_hindering,quick_wins,ambitious_workflows}."""
import json, html, sys, os, math

q = json.load(open(sys.argv[1]))
n = json.load(open(sys.argv[2])) if len(sys.argv) > 2 and os.path.exists(sys.argv[2]) else {}
ts = sys.argv[3] if len(sys.argv) > 3 else "unknown"
out = sys.argv[4] if len(sys.argv) > 4 else "myinsights.html"
E = html.escape

# ---- Linear design tokens (design-md/linear/DESIGN.md) ----
C = dict(bg="#08090A", panel="#0F1011", panel2="#141516", elev="#1C1C1F",
         ink="#F7F8F8", body="#D0D6E0", muted="#8A8F98", faint="#62666D",
         line="#23252A", line2="#34343A",
         indigo="#5E6AD2", link="#7070FF", hover="#828FFF",
         blue="#4EA7FC", teal="#00B8CC", green="#27A644", plan="#68CC58",
         yellow="#F0BF00", orange="#FC7840", red="#EB5757")

N_FULL = q.get("sessions", 0)
N_FACET = q.get("facet_n", q.get("facet_count", 0))
def fmt(x): return f"{x:,}" if isinstance(x, int) else x
def g(d, k, default=""): return (d or {}).get(k, default)

def badge_full():   return f'<span class="badge bf-full">full corpus · n={fmt(N_FULL)}</span>'
def badge_sample(): return f'<span class="badge bf-samp">sampled · n={N_FACET}</span>'
def badge_for(kind): return badge_full() if kind == "full" else badge_sample()

def bars(pairs, color, labelmap=None, maxn=None, unit=""):
    if not pairs: return '<p class="cap">no data</p>'
    mx = maxn or max(v for _, v in pairs) or 1
    rows = []
    for name, v in pairs:
        label = (labelmap or {}).get(name, str(name).replace("_", " "))
        rows.append(
            f'<div class="bar"><span class="bl">{E(str(label))}</span>'
            f'<span class="bt"><span class="bf" style="width:{100*v/mx:.1f}%;background:{color}"></span></span>'
            f'<span class="bv">{fmt(v)}{unit}</span></div>')
    return "".join(rows)

def hour_spark():
    data = q.get("by_hour", [])
    if not data: return ""
    mx = max(v for _, v in data) or 1
    W, H, pad, bw = 620, 96, 6, 620/24
    b = []
    for h, v in data:
        bh = (H - pad*2 - 10) * v / mx
        col = C["indigo"] if 8 <= h <= 20 else C["line2"]
        b.append(f'<rect x="{h*bw+1:.1f}" y="{H-pad-10-bh:.1f}" width="{bw-2:.1f}" height="{max(bh,0.5):.1f}" rx="1.5" fill="{col}"><title>{h:02d}:00 — {v} msgs</title></rect>')
    ticks = "".join(f'<text x="{h*bw+bw/2:.1f}" y="{H-1}" class="tick">{h:02d}</text>' for h in (0,3,6,9,12,15,18,21,23))
    return f'<svg viewBox="0 0 {W} {H}" width="100%" height="{H}" preserveAspectRatio="none" role="img" aria-label="Messages by hour">{"".join(b)}{ticks}</svg>'

OUT_ORDER = [("fully_achieved","Fully",C["green"]),("mostly_achieved","Mostly",C["plan"]),
             ("partially_achieved","Partial",C["yellow"]),("unclear_from_transcript","Unclear (API death)",C["faint"]),
             ("not_achieved","Not achieved",C["red"])]
outc = dict(q.get("facet_outcomes", [])); otot = sum(outc.values()) or 1
def donut():
    r, cx, cy, sw = 60, 84, 84, 24; circ = 2*math.pi*r; off = 0.0; segs = []
    for k,label,col in OUT_ORDER:
        v = outc.get(k, 0)
        if not v: continue
        fr = v/otot
        segs.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{col}" stroke-width="{sw}" stroke-dasharray="{circ*fr:.2f} {circ:.2f}" stroke-dashoffset="{-off*circ:.2f}" transform="rotate(-90 {cx} {cy})"><title>{label}: {v}</title></circle>')
        off += fr
    win = round(100*(outc.get("fully_achieved",0)+outc.get("mostly_achieved",0))/otot)
    return f'<svg viewBox="0 0 168 168" width="168" height="168">{"".join(segs)}<text x="{cx}" y="{cy-2}" text-anchor="middle" class="dn">{win}%</text><text x="{cx}" y="{cy+15}" text-anchor="middle" class="dl">landed</text></svg>'
def out_legend():
    return "<ul class='legend'>" + "".join(
        f'<li><span class="dot" style="background:{c}"></span><span class="lg">{l}</span><span class="lv">{outc.get(k,0)}</span></li>'
        for k,l,c in OUT_ORDER if outc.get(k,0)) + "</ul>"

FR_LABELS = {"buggy_code":"Buggy code","wrong_approach":"Wrong approach","misunderstood_request":"Misread request",
             "user_rejected_action":"You rejected an action","missing_context":"Missing context"}
TOOL_LABELS = {"mcp__claude-in-chrome__computer":"chrome:computer","mcp__claude-in-chrome__javascript_tool":"chrome:js",
               "mcp__chrome-devtools__evaluate_script":"devtools:js","mcp__chrome-devtools__navigate_page":"devtools:nav"}

areas = q.get("top_project_areas", [])
scratch = next((v for nm,v in areas if nm=="scratch/worktree"), 0)
named = [(nm,v) for nm,v in areas if nm!="scratch/worktree"][:9]
est_upper = q.get("input_tokens",0)/1e6*5 + q.get("output_tokens",0)/1e6*25

def code(s): return f'<pre class="code">{E(str(s))}</pre>' if s else ""
def prompt_box(s): return f'<div class="prompt"><span class="pl">copyable prompt</span><pre class="code">{E(str(s))}</pre></div>' if s else ""
def scaffold_tag(s): return f'<span class="scaf">{E(str(s))}</span>' if s else ""

# ================= SCORECARD =================
# Deterministic formulas over quant.json. Each factor: name, score 0-100, provenance
# ("full" n=sessions | "samp" n=facets), evidence, lever, weight (%). Targets for
# cadence/delegation are stated in the evidence line — they are chosen yardsticks,
# not industry benchmarks.
def compute_scores():
    fn = max(N_FACET, 1)
    fric = dict(q.get("facet_frictions", []))
    landed = outc.get("fully_achieved",0) + outc.get("mostly_achieved",0)
    unclear = outc.get("unclear_from_transcript", 0)
    buggy = fric.get("buggy_code", 0); wrong = fric.get("wrong_approach", 0)
    commits = q.get("commits", 0); pushes = q.get("pushes", 0)
    days = max(q.get("active_days", 1), 1)
    cadence = commits / days
    worktree = next((v for nm,v in areas if nm=="scratch/worktree"), 0)
    agents = q.get("task_agent_sessions", 0)
    errs = q.get("tool_errors", 0)
    top_calls = sum(v for _,v in q.get("top_tools", [])) or 1
    nf = max(N_FULL, 1)
    F = []
    F.append(dict(name="Ship cadence", score=min(100.0, 100*cadence/25), kind="full", w=10,
        ev=f"{fmt(commits)} commits over {days} active days ≈ {cadence:.0f}/day, scored vs a 25/day target",
        lever="Already elite — protect it; don't let review debt slow the pipeline."))
    F.append(dict(name="Tool reliability", score=100*(1 - errs/top_calls), kind="full", w=5,
        ev=f"{fmt(errs)} tool errors vs {fmt(top_calls)} top-12 tool calls (error rate is an upper bound — denominator excludes long-tail tools)",
        lever="Mostly environmental; pre-flight known blockers (ports, auth, dead servers)."))
    F.append(dict(name="Survival rate", score=100*(1 - unclear/fn), kind="samp", w=10,
        ev=f"{unclear} of {fn} analyzed sessions died to output-token-limit errors",
        lever="Budgeted runs with a forced reboot handoff before the ceiling."))
    F.append(dict(name="Landing rate", score=100*landed/fn, kind="samp", w=20,
        ev=f"{landed} of {fn} analyzed sessions ended fully or mostly achieved",
        lever="Tighten done-criteria up front; keep the verify gate mandatory."))
    F.append(dict(name="Approach accuracy", score=100*(1 - wrong/fn), kind="samp", w=15,
        ev=f"wrong_approach flagged in {wrong} of {fn} analyzed sessions",
        lever="5-minute feasibility probe + named fallback before coding against external systems."))
    F.append(dict(name="Isolation discipline", score=100*worktree/nf, kind="full", w=10,
        ev=f"{fmt(worktree)} of {fmt(nf)} sessions ran in isolated scratch/worktree areas",
        lever="Default every multi-file build into a worktree off origin/main."))
    F.append(dict(name="Clean first pass", score=100*(1 - buggy/fn), kind="samp", w=15,
        ev=f"buggy_code flagged in {buggy} of {fn} analyzed sessions",
        lever="Failing test (or assertion checklist) BEFORE editing 2+ files."))
    F.append(dict(name="Push-through", score=100*pushes/max(commits,1), kind="full", w=10,
        ev=f"{fmt(pushes)} pushes vs {fmt(commits)} commits — work that actually left the machine",
        lever="Land or discard: fewer stranded local commits — unpushed work is invisible to teammates and at risk on a single machine."))
    F.append(dict(name="Delegation leverage", score=min(100.0, 100*(agents/nf)/0.20), kind="full", w=5,
        ev=f"{agents} of {fmt(nf)} sessions used task agents, scored vs a 20% target",
        lever="Route search/mechanical work to haiku/sonnet subagents; keep Opus for judgment."))
    total_w = sum(f["w"] for f in F)
    composite = sum(f["score"]*f["w"] for f in F) / total_w
    return sorted(F, key=lambda f: -f["score"]), composite

def grade_of(s):
    for cut, letter in ((93,"A+"),(85,"A"),(78,"A−"),(70,"B+"),(62,"B"),(55,"B−"),(45,"C+"),(35,"C")):
        if s >= cut: return letter
    return "D"
def grade_color(s):
    if s >= 78: return C["green"]
    if s >= 55: return C["blue"]
    if s >= 35: return C["yellow"]
    return C["red"]

FACTORS, COMPOSITE = compute_scores()
COMP_GRADE = grade_of(COMPOSITE); COMP_COL = grade_color(COMPOSITE)

def gauge():
    r, cx, cy, sw = 62, 78, 78, 11
    circ = 2*math.pi*r; frac = max(min(COMPOSITE/100, 1), 0)
    return (f'<svg viewBox="0 0 156 156" width="156" height="156" role="img" aria-label="Composite score">'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{C["line"]}" stroke-width="{sw}"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{COMP_COL}" stroke-width="{sw}" stroke-linecap="round" '
            f'stroke-dasharray="{circ*frac:.2f} {circ:.2f}" transform="rotate(-90 {cx} {cy})"/>'
            f'<text x="{cx}" y="{cy-4}" text-anchor="middle" class="gg">{COMP_GRADE}</text>'
            f'<text x="{cx}" y="{cy+20}" text-anchor="middle" class="gs">{COMPOSITE:.0f} / 100</text></svg>')

rank_rows = []
for i, f in enumerate(FACTORS, 1):
    gr = grade_of(f["score"]); col = grade_color(f["score"])
    rank_rows.append(
        f'<div class="rk">'
        f'<span class="rk-n">{i:02d}</span>'
        f'<div class="rk-main">'
        f'<div class="rk-head"><span class="rk-name">{E(f["name"])}</span>'
        f'<span class="pill" style="color:{col};border-color:{col}55;background:{col}14">{gr}</span>'
        f'{badge_for(f["kind"])}'
        f'<span class="rk-score">{f["score"]:.0f}</span></div>'
        f'<div class="rk-bar"><span style="width:{f["score"]:.1f}%;background:{col}"></span></div>'
        f'<div class="rk-ev">{E(f["ev"])} · weight {f["w"]}%</div>'
        f'<div class="rk-lever">↗ {E(f["lever"])}</div>'
        f'</div></div>')
rank_html = "".join(rank_rows)

# ---------- narrative pieces ----------
istyle = n.get("interaction_style", {})
if isinstance(istyle, str): istyle = {"narrative": istyle, "key_pattern": ""}

proj_parts = []
for p in n.get("project_areas", []):
    cnt = f'<span class="pa-c">~{p.get("session_count")} sessions</span>' if p.get("session_count") else ""
    proj_parts.append(f'<div class="pa"><div class="pa-h"><span class="pa-n">{E(g(p,"name"))}</span>{cnt}</div>'
                      f'<div class="pa-g">{E(g(p,"description") or g(p,"gist"))}</div></div>')
proj_html = "".join(proj_parts) or '<p class="cap">narrative pending</p>'

ww = n.get("what_works", {})
ww_intro = g(ww, "intro"); ww_items = ww.get("impressive_workflows", []) if isinstance(ww, dict) else []
if not ww_items and isinstance(n.get("what_works"), list):
    ww_items = [{"title":"", "description":x} for x in n["what_works"]]
ww_html = "".join(f'<div class="wf"><div class="wf-t">{E(g(w,"title") or "•")}</div><div class="wf-d">{E(g(w,"description"))}</div></div>' for w in ww_items) or '<p class="cap">—</p>'

fr = n.get("friction", {})
fr_intro = g(fr, "intro"); fr_cats = fr.get("categories", []) if isinstance(fr, dict) else []
if not fr_cats and isinstance(n.get("friction"), list):
    fr_cats = [{"category":g(x,"category"),"description":g(x,"fix"),"examples":[]} for x in n["friction"]]
def fr_examples(ex): return ("<ul class='ex'>"+"".join(f"<li>{E(e)}</li>" for e in ex)+"</ul>") if ex else ""
fr_html = "".join(
    f'<div class="fc"><div class="fc-c">{E(g(c,"category"))}</div><div class="fc-d">{E(g(c,"description"))}</div>{fr_examples(c.get("examples",[]))}</div>'
    for c in fr_cats) or '<p class="cap">—</p>'

sug = n.get("suggestions", {})
if isinstance(sug, list): sug = {"usage_patterns":[{"title":"","suggestion":x,"copyable_prompt":""} for x in sug]}
cma = sug.get("claude_md_additions", []); ftt = sug.get("features_to_try", []); ups = sug.get("usage_patterns", [])
cma_html = "".join(f'<div class="sg"><div class="sg-t">{E(g(a,"addition"))}{scaffold_tag(g(a,"prompt_scaffold"))}</div><div class="sg-w">why — {E(g(a,"why"))}</div></div>' for a in cma)
ftt_html = "".join(f'<div class="sg"><div class="sg-t">{E(g(f,"feature"))} <span class="sg-1">{E(g(f,"one_liner"))}</span></div><div class="sg-w">{E(g(f,"why_for_you"))}</div>{code(g(f,"example_code"))}</div>' for f in ftt)
ups_parts = []
for u in ups:
    detail = f'<p class="ups-d">{E(g(u,"detail"))}</p>' if g(u,"detail") else ""
    ups_parts.append(f'<div class="sg"><div class="sg-t">{E(g(u,"title"))}</div><div class="sg-w">{E(g(u,"suggestion"))}</div>{detail}{prompt_box(g(u,"copyable_prompt"))}</div>')
ups_html = "".join(ups_parts)

oth = n.get("on_the_horizon", {})
oth_intro = g(oth, "intro"); ops = oth.get("opportunities", []) if isinstance(oth, dict) else []
oth_parts = []
for o in ops:
    how = f'<div class="how">How to try — {E(g(o,"how_to_try"))}</div>' if g(o,"how_to_try") else ""
    oth_parts.append(f'<div class="op"><div class="op-t">{E(g(o,"title"))}</div><div class="op-d">{E(g(o,"whats_possible"))}</div>{how}{prompt_box(g(o,"copyable_prompt"))}</div>')
oth_html = "".join(oth_parts) or '<p class="cap">—</p>'

fe = n.get("fun_ending", {})
if isinstance(fe, str): fe = {"headline": fe, "detail": ""}
ag = n.get("at_a_glance", {})

SNO = iter(range(1, 20))
def h2(title, extra=""):
    return f'<h2><span class="sno">{next(SNO):02d}</span>{title}{extra}</h2>'

HTMLOUT = f"""<style>
:root{{--bg:{C['bg']};--panel:{C['panel']};--p2:{C['panel2']};--elev:{C['elev']};--ink:{C['ink']};--body:{C['body']};--muted:{C['muted']};--faint:{C['faint']};--line:{C['line']};--line2:{C['line2']};--indigo:{C['indigo']};--link:{C['link']};--hover:{C['hover']};--blue:{C['blue']};--teal:{C['teal']};--green:{C['green']};--yellow:{C['yellow']};--orange:{C['orange']};--red:{C['red']}}}
*{{box-sizing:border-box}}
.wrap{{max-width:1120px;margin:0 auto;padding:48px 24px 72px;background:var(--bg);color:var(--ink);font-family:"Inter Variable","SF Pro Display",-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;line-height:1.6;letter-spacing:-.011em}}
.mono{{font-family:"Berkeley Mono",ui-monospace,"SF Mono",Menlo,monospace}}
.eyebrow{{font-family:"Berkeley Mono",ui-monospace,monospace;font-size:12px;letter-spacing:.18em;text-transform:uppercase;color:var(--link);margin:0 0 10px;font-weight:510}}
h1{{font-size:34px;line-height:1.12;margin:0 0 12px;font-weight:590;text-wrap:balance;letter-spacing:-.022em;color:var(--ink)}}
.lede{{color:var(--muted);font-size:15px;max-width:72ch;margin:0 0 4px;letter-spacing:-.011em}}
.metastrip{{font-family:"Berkeley Mono",ui-monospace,monospace;font-size:13px;color:var(--body);margin:2px 0 16px;line-height:1.8;font-variant-numeric:tabular-nums}}
.metastrip b{{color:var(--teal);font-weight:590}} .metastrip .sep{{color:var(--faint);padding:0 8px}}
.tiers{{display:flex;margin:20px 0 4px;border:1px solid var(--line);border-radius:12px;overflow:hidden;max-width:640px;background:var(--panel)}}
.tier{{flex:1;padding:14px 16px}} .tier+.tier{{border-left:1px solid var(--line)}}
.tier .tn{{font-family:"Berkeley Mono",ui-monospace,monospace;font-size:22px;font-weight:680;font-variant-numeric:tabular-nums}}
.tier .tl{{color:var(--muted);font-size:11.5px;margin-top:3px}}
.t1 .tn{{color:var(--faint)}} .t2 .tn{{color:var(--teal)}} .t3 .tn{{color:var(--yellow)}}
.caveat{{font-family:"Berkeley Mono",ui-monospace,monospace;font-size:12px;color:var(--yellow);background:#F0BF0010;border:1px solid #F0BF0030;border-radius:8px;padding:10px 13px;margin:16px 0 0;max-width:82ch;line-height:1.55}}
h2{{font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:var(--muted);font-family:"Berkeley Mono",ui-monospace,monospace;margin:0 0 16px;font-weight:510;display:flex;align-items:center;gap:10px;flex-wrap:wrap}}
.sno{{color:var(--faint);font-weight:400}}
.badge{{font-family:"Berkeley Mono",ui-monospace,monospace;font-size:10px;letter-spacing:.03em;padding:2px 9px;border-radius:9999px;text-transform:none;font-weight:510}}
.bf-full{{background:#00B8CC14;color:#4fd2e2;border:1px solid #00B8CC3d}} .bf-samp{{background:#F0BF0014;color:#f0cf4d;border:1px solid #F0BF003d}}
.section{{margin-top:48px}}
.card{{background:var(--panel);border:1px solid var(--line);border-radius:16px;padding:22px;box-shadow:0px 3px 12px rgba(0,0,0,.09)}}
.grid{{display:grid;gap:16px}} .two{{grid-template-columns:1fr 1fr}} .three{{grid-template-columns:repeat(3,1fr)}}
.kpis{{grid-template-columns:repeat(4,1fr)}} .kpi{{background:var(--panel);border:1px solid var(--line);border-radius:16px;padding:18px}}
.kpi .n{{font-family:"Berkeley Mono",ui-monospace,monospace;font-size:26px;font-weight:680;font-variant-numeric:tabular-nums;letter-spacing:-.02em}}
.kpi .l{{color:var(--muted);font-size:12px;font-family:"Berkeley Mono",ui-monospace,monospace;margin-top:4px}} .kpi .s{{color:var(--faint);font-size:11px;margin-top:5px;line-height:1.4}}
.bar{{display:grid;grid-template-columns:150px 1fr 64px;align-items:center;gap:12px;margin:8px 0;font-size:13px}}
.bl{{color:var(--muted);text-align:right;font-size:12.5px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}}
.bt{{background:rgba(255,255,255,.04);border-radius:6px;height:14px;overflow:hidden;border:1px solid var(--line)}} .bf{{display:block;height:100%;border-radius:5px}}
.bv{{font-family:"Berkeley Mono",ui-monospace,monospace;font-variant-numeric:tabular-nums;color:var(--muted);font-size:12.5px;text-align:right}}
.cap{{color:var(--muted);font-size:12.5px;font-style:italic;margin:12px 2px 0;line-height:1.55}}
.tick{{fill:var(--faint);font-size:9.5px;font-family:ui-monospace,monospace;text-anchor:middle}}
.narr{{font-size:15px;line-height:1.72;max-width:74ch;color:var(--body);letter-spacing:-.011em}}
.keyp{{margin-top:14px;padding:12px 15px;border-left:2px solid var(--indigo);background:#5E6AD214;border-radius:0 8px 8px 0;font-size:14px;color:var(--ink)}}
.intro{{color:var(--muted);font-size:14.5px;max-width:74ch;margin:0 0 16px}}
.pa{{padding:13px 0;border-bottom:1px solid var(--line)}} .pa:last-child{{border:none}}
.pa-h{{display:flex;justify-content:space-between;gap:10px;align-items:baseline}} .pa-n{{font-weight:590;font-size:14.5px;letter-spacing:-.011em}}
.pa-c{{font-family:"Berkeley Mono",ui-monospace,monospace;font-size:11px;color:var(--teal);flex:none}} .pa-g{{color:var(--muted);font-size:13px;margin-top:3px}}
.wf{{padding:14px 0;border-bottom:1px solid var(--line)}} .wf:last-child{{border:none}}
.wf-t{{font-weight:590;font-size:15px;color:var(--teal);letter-spacing:-.011em}} .wf-d{{color:var(--body);font-size:14px;margin-top:4px;line-height:1.62}}
.fc{{padding:14px 0;border-bottom:1px solid var(--line)}} .fc:last-child{{border:none}}
.fc-c{{font-family:"Berkeley Mono",ui-monospace,monospace;color:var(--red);font-size:13.5px;font-weight:510}} .fc-d{{color:var(--body);font-size:14px;margin-top:4px;line-height:1.62}}
ul.ex{{margin:8px 0 0;padding-left:18px}} ul.ex li{{color:var(--muted);font-size:13px;margin:5px 0;line-height:1.5}}
.sg{{padding:15px 0;border-bottom:1px solid var(--line)}} .sg:last-child{{border:none}}
.sg-t{{font-weight:590;font-size:14.5px;letter-spacing:-.011em}} .sg-1{{font-weight:400;color:var(--muted);font-size:13px}} .sg-w{{color:var(--muted);font-size:13.5px;margin-top:4px;line-height:1.55}}
.scaf{{display:inline-block;margin-left:8px;font-family:"Berkeley Mono",ui-monospace,monospace;font-size:10.5px;letter-spacing:.02em;color:var(--hover);background:#5E6AD214;border:1px solid #828FFF33;border-radius:9999px;padding:1px 9px;vertical-align:middle;font-weight:510}}
p.ups-d{{color:var(--body);font-size:13.5px;margin:8px 0 0;line-height:1.62;max-width:80ch}}
pre.code{{background:{C['bg']};border:1px solid var(--line);border-radius:12px;padding:14px 16px;margin:10px 0 0;overflow-x:auto;font-family:"Berkeley Mono",ui-monospace,monospace;font-size:12.5px;line-height:1.5;color:var(--body);white-space:pre}}
.prompt{{margin-top:10px}} .prompt .pl{{font-family:"Berkeley Mono",ui-monospace,monospace;font-size:10px;letter-spacing:.1em;text-transform:uppercase;color:var(--link)}}
.op{{padding:16px 0;border-bottom:1px solid var(--line)}} .op:last-child{{border:none}}
.op-t{{font-weight:590;font-size:15.5px;color:var(--hover);letter-spacing:-.011em}} .op-d{{color:var(--body);font-size:14px;margin-top:5px;line-height:1.65}} .how{{color:var(--muted);font-size:13px;margin-top:8px}}
.glance{{grid-template-columns:1fr 1fr}} .gq h3{{margin:0 0 6px;font-size:12.5px;font-family:"Berkeley Mono",ui-monospace,monospace;letter-spacing:.06em;font-weight:510}}
.gq p{{margin:0;color:var(--body);font-size:13.5px;line-height:1.62}} .gq.w h3{{color:var(--teal)}} .gq.h h3{{color:var(--yellow)}} .gq.q h3{{color:var(--blue)}} .gq.a h3{{color:var(--hover)}}
.donutwrap{{display:flex;gap:22px;align-items:center;flex-wrap:wrap}}
.dn{{font-family:ui-monospace,monospace;font-size:27px;font-weight:680;fill:var(--ink)}} .dl{{font-family:ui-monospace,monospace;font-size:10px;fill:var(--muted)}}
.legend{{list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:7px;min-width:170px}}
.legend li{{display:flex;align-items:center;gap:9px;font-size:12.5px}} .dot{{width:10px;height:10px;border-radius:3px;flex:none}}
.lg{{flex:1;color:var(--muted)}} .lv{{font-family:"Berkeley Mono",ui-monospace,monospace;font-variant-numeric:tabular-nums}}
.stat{{text-align:center;padding:16px 10px}} .stat .n{{font-family:"Berkeley Mono",ui-monospace,monospace;font-size:23px;font-weight:680}} .stat .l{{color:var(--muted);font-size:11.5px;margin-top:4px}}
.scoregrid{{display:grid;grid-template-columns:280px 1fr;gap:16px;align-items:start}}
.gauge-card{{display:flex;flex-direction:column;align-items:center;text-align:center;gap:6px;padding:28px 22px}}
.gg{{font-family:"Berkeley Mono",ui-monospace,monospace;font-size:34px;font-weight:680;fill:var(--ink)}}
.gs{{font-family:"Berkeley Mono",ui-monospace,monospace;font-size:11px;fill:var(--muted)}}
.gauge-t{{font-weight:590;font-size:14.5px;margin-top:4px;letter-spacing:-.011em}}
.gauge-s{{color:var(--muted);font-size:12px;line-height:1.55}}
.rk{{display:flex;gap:14px;padding:14px 0;border-bottom:1px solid var(--line)}} .rk:last-child{{border:none}}
.rk-n{{font-family:"Berkeley Mono",ui-monospace,monospace;font-size:12px;color:var(--faint);padding-top:2px;flex:none;width:22px}}
.rk-main{{flex:1;min-width:0}}
.rk-head{{display:flex;align-items:center;gap:9px;flex-wrap:wrap}}
.rk-name{{font-weight:590;font-size:14px;letter-spacing:-.011em}}
.pill{{font-family:"Berkeley Mono",ui-monospace,monospace;font-size:11px;font-weight:590;padding:1px 9px;border-radius:9999px;border:1px solid}}
.rk-score{{margin-left:auto;font-family:"Berkeley Mono",ui-monospace,monospace;font-size:13px;font-weight:590;font-variant-numeric:tabular-nums;color:var(--body)}}
.rk-bar{{background:rgba(255,255,255,.04);border:1px solid var(--line);border-radius:6px;height:10px;overflow:hidden;margin:8px 0 7px}}
.rk-bar span{{display:block;height:100%;border-radius:5px}}
.rk-ev{{color:var(--muted);font-size:12.5px;line-height:1.5}}
.rk-lever{{color:var(--faint);font-size:12px;margin-top:3px}} .rk-lever::first-letter{{color:var(--link)}}
footer{{margin-top:48px;padding-top:18px;border-top:1px solid var(--line);color:var(--faint);font-size:12px;font-family:"Berkeley Mono",ui-monospace,monospace;display:flex;justify-content:space-between;flex-wrap:wrap;gap:8px}}
@media(max-width:820px){{.kpis,.three{{grid-template-columns:repeat(2,1fr)}}.two,.glance,.scoregrid{{grid-template-columns:1fr}}.tiers{{flex-direction:column}}.tier+.tier{{border-left:none;border-top:1px solid var(--line)}}.bar{{grid-template-columns:110px 1fr 56px}}}}
</style>
<div class="wrap">
  <p class="eyebrow">Claude Code · myinsights · all logins merged</p>
  <h1>{E(n.get("headline","Your full picture across every login"))}</h1>
  <p class="metastrip"><b>{fmt(N_FULL)}</b> sessions counted<span class="sep">·</span><b>{N_FACET}</b> narrated<span class="sep">·</span><b>{fmt(q.get('raw_transcripts',0))}</b> on disk<span class="sep">·</span><b>{fmt(q.get('user_msgs',0))}</b> your messages<span class="sep">·</span><b>{q.get('total_hours',0)}h</b> wall-clock*<span class="sep">·</span><b>{fmt(q.get('commits',0))}</b> commits<span class="sep">·</span><b>{q.get('active_days',0)}</b> active days</p>
  <p class="lede">The report the built-in <span class="mono">/insights</span> can't give you: your <b>whole local corpus</b>, both logins merged. <span class="mono">/login</span> swaps only your identity — it never erases session history.</p>

  <div class="tiers">
    <div class="tier t1"><div class="tn">{fmt(q.get('raw_transcripts',0))}</div><div class="tl">raw session files on disk</div></div>
    <div class="tier t2"><div class="tn">{fmt(N_FULL)}</div><div class="tl">with metrics → quant layer (exhaustive)</div></div>
    <div class="tier t3"><div class="tn">{N_FACET}</div><div class="tl">with facets → narrative (sample)</div></div>
  </div>
  <p class="cap" style="max-width:82ch">Built-in <span class="mono">/insights</span> narrated ~131. This narrates {N_FACET} and <b>counts all {fmt(N_FULL)}</b>.</p>
  <p class="caveat">⚠︎ Merged, not segmented. Session history on disk carries <b>no account tag</b>, so this cannot split work vs personal — and both logins are the same person who asked for a merged view. Full-corpus stats (n={fmt(N_FULL)}) and sampled narrative stats (n={N_FACET}) are badged separately and never blended.</p>

  <section class="section">
    {h2("Scorecard — every factor, ranked")}
    <div class="scoregrid">
      <div class="card gauge-card">
        {gauge()}
        <div class="gauge-t">Composite: {COMP_GRADE}</div>
        <div class="gauge-s">Weighted mean of the 9 factors on the right. Weights shown per row; outcome quality carries the most (landing 20%, clean-pass 15%, approach 15%).</div>
      </div>
      <div class="card">{rank_html}</div>
    </div>
    <p class="cap" style="max-width:92ch">Every score is a disclosed formula over the corpus data — nothing is model-vibes. Sampled-badge rows are measured on the {N_FACET} analyzed sessions only; full-badge rows on all {fmt(N_FULL)}. The 25-commits/day and 20%-delegation yardsticks are chosen targets, not industry benchmarks.</p>
  </section>

  <section class="section">
    {h2("At a glance")}
    <div class="grid glance">
      <div class="card gq w"><h3>What's working</h3><p>{E(g(ag,"whats_working","—"))}</p></div>
      <div class="card gq h"><h3>What's hindering</h3><p>{E(g(ag,"whats_hindering","—"))}</p></div>
      <div class="card gq q"><h3>Quick wins</h3><p>{E(g(ag,"quick_wins","—"))}</p></div>
      <div class="card gq a"><h3>Ambitious workflows</h3><p>{E(g(ag,"ambitious_workflows","—"))}</p></div>
    </div>
  </section>

  <section class="section">
    {h2("By the numbers ", badge_full())}
    <div class="grid kpis">
      <div class="kpi"><div class="n">{fmt(N_FULL)}</div><div class="l">sessions</div><div class="s">{q.get('active_days')} active days · median {q.get('median_session_min')}m</div></div>
      <div class="kpi"><div class="n">{q.get('output_tokens',0)//1_000_000}M</div><div class="l">output tokens</div><div class="s">{q.get('input_tokens',0)//1_000_000}M in · {q.get('output_tokens',1)/max(q.get('input_tokens',1),1):.1f}:1</div></div>
      <div class="kpi"><div class="n">{fmt(q.get('commits',0))}</div><div class="l">commits</div><div class="s">{q.get('pushes')} pushes · +{fmt(q.get('lines_added',0))}/−{fmt(q.get('lines_removed',0))}</div></div>
      <div class="kpi"><div class="n">{q.get('total_hours')}h</div><div class="l">wall-clock*</div><div class="s">*summed across overlapping terminals — NOT calendar</div></div>
    </div>
  </section>

  <section class="section">
    {h2("How you work ", badge_full())}
    <p class="narr">{E(g(istyle,"narrative","(narrative pending)"))}</p>
    {f'<div class="keyp"><b>Signature pattern:</b> {E(g(istyle,"key_pattern"))}</div>' if g(istyle,"key_pattern") else ""}
  </section>

  <section class="section">
    {h2("Where the work lives ", badge_sample())}
    <div class="grid two">
      <div class="card">{proj_html}</div>
      <div class="card">
        <div class="mono" style="font-size:12px;color:var(--muted);margin-bottom:10px">NAMED PROJECT PATHS {badge_full()}</div>
        {bars(named, C['teal'])}
        <p class="cap">Plus <b>{fmt(scratch)}</b> sessions in ephemeral worktrees/scratch (~{round(100*scratch/max(N_FULL,1))}% of all) — not one project, excluded from the ranking.</p>
      </div>
    </div>
  </section>

  <section class="section">
    {h2("What you used ", badge_full())}
    <div class="grid two">
      <div class="card"><div class="mono" style="font-size:12px;color:var(--muted);margin-bottom:10px">TOOL CALLS</div>{bars(q.get("top_tools",[])[:10], C['indigo'], TOOL_LABELS)}</div>
      <div class="card"><div class="mono" style="font-size:12px;color:var(--muted);margin-bottom:10px">LANGUAGES</div>{bars(q.get("top_languages",[])[:8], C['blue'])}</div>
    </div>
    <div class="grid three" style="margin-top:16px">
      <div class="card stat"><div class="n" style="color:var(--teal)">{q.get('task_agent_sessions',0)}</div><div class="l">sessions using task agents</div></div>
      <div class="card stat"><div class="n" style="color:var(--blue)">{q.get('mcp_sessions',0)}</div><div class="l">sessions using MCP</div></div>
      <div class="card stat"><div class="n" style="color:var(--hover)">{q.get('websearch_sessions',0)}</div><div class="l">sessions using web search</div></div>
    </div>
  </section>

  <section class="section">
    {h2("When you work ", badge_full() + '<span style="color:var(--faint)">— messages by hour</span>')}
    <div class="card">{hour_spark()}<p class="cap">Lit bars = 08:00–20:00. Busiest day: {q.get('busiest_days',[['—',0]])[0][0]} ({q.get('busiest_days',[['—',0]])[0][1]} sessions). A rhythm, not a login-detector.</p></div>
  </section>

  <section class="section">
    {h2("Outcomes &amp; friction ", badge_sample())}
    <div class="grid two">
      <div class="card"><div class="mono" style="font-size:12px;color:var(--muted);margin-bottom:12px">OUTCOMES</div><div class="donutwrap">{donut()}{out_legend()}</div></div>
      <div class="card"><div class="mono" style="font-size:12px;color:var(--muted);margin-bottom:12px">TOP FRICTION</div>{bars(q.get("facet_frictions",[]), C['red'], FR_LABELS)}<p class="cap">Across the {N_FACET} narrated sessions only.</p></div>
    </div>
  </section>

  <section class="section">
    {h2("What works ", badge_sample())}
    {f'<p class="intro">{E(ww_intro)}</p>' if ww_intro else ""}
    <div class="card">{ww_html}</div>
  </section>

  <section class="section">
    {h2("Where things go wrong ", badge_sample())}
    {f'<p class="intro">{E(fr_intro)}</p>' if fr_intro else ""}
    <div class="card">{fr_html}</div>
  </section>

  <section class="section">
    {h2("Suggestions ", badge_sample())}
    {f'<div class="card" style="margin-bottom:16px"><div class="mono" style="font-size:12px;color:var(--muted);margin-bottom:6px">CLAUDE.md ADDITIONS</div>{cma_html}</div>' if cma_html else ""}
    {f'<div class="card" style="margin-bottom:16px"><div class="mono" style="font-size:12px;color:var(--muted);margin-bottom:6px">FEATURES TO TRY</div>{ftt_html}</div>' if ftt_html else ""}
    {f'<div class="card"><div class="mono" style="font-size:12px;color:var(--muted);margin-bottom:6px">USAGE PATTERNS</div>{ups_html}</div>' if ups_html else ""}
  </section>

  <section class="section">
    {h2("On the horizon ", badge_sample())}
    {f'<p class="intro">{E(oth_intro)}</p>' if oth_intro else ""}
    <div class="card">{oth_html}</div>
  </section>

  <section class="section">
    {h2("The numbers that sting ", badge_full())}
    <div class="grid three">
      <div class="card stat"><div class="n" style="color:var(--yellow)">{q.get('output_tokens',1)/max(q.get('input_tokens',1),1):.1f}:1</div><div class="l">output : input ({q.get('output_tokens',0)//1_000_000}M vs {q.get('input_tokens',0)//1_000_000}M)</div></div>
      <div class="card stat"><div class="n" style="color:var(--red)">{fmt(q.get('tool_errors',0))}</div><div class="l">tool errors survived</div></div>
      <div class="card stat"><div class="n" style="color:var(--teal)">≤ ${est_upper/1000:.1f}k</div><div class="l">upper-bound cost IF all Opus-rate*</div></div>
    </div>
    <p class="cap">*Model tier isn't logged per session; real spend is well below this (much ran on Sonnet/Haiku subagents). Directional ceiling, not a bill.</p>
  </section>

  <section class="section">
    {h2("One last thing")}
    <div class="card"><div class="wf-t" style="color:var(--orange);font-size:16px">{E(g(fe,"headline","—"))}</div><p class="narr" style="margin-top:8px">{E(g(fe,"detail",""))}</p></div>
  </section>

  <footer>
    <span>merged · all local logins · {fmt(N_FULL)} counted · {N_FACET} narrated · {fmt(q.get('raw_transcripts',0))} raw files</span>
    <span>generated {E(ts)} · read-only · local-only · no token emitted</span>
  </footer>
</div>"""
open(out, "w").write(HTMLOUT)
print("wrote", out, len(HTMLOUT), "bytes | composite", f"{COMPOSITE:.1f}", COMP_GRADE)
