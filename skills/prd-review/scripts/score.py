#!/usr/bin/env python3
"""
Deterministic PRD heuristic linter.

Usage:
    python3 score.py <path-to-prd.md>                 # score a file (auto-detects mode)
    python3 score.py - --mode design                  # score stdin, force design mode
    python3 score.py prd.md --mode functional         # force functional mode

Modes:
    functional (default for product/spec PRDs) - testability = Gherkin acceptance criteria;
        measurable NFRs = latency/uptime/size targets.
    design     (UX / visual / design-system PRDs) - testability = a definition-of-done plus
        checkable design metrics; measurable NFRs = accessibility / token targets.
    auto       - pick functional or design from the document's own signals (the default).

Measures how WELL-FORMED a PRD is - not whether it describes the right product.
Prints a readable summary, then a fenced ---JSON--- block for a caller to parse.
"""
import sys, re, json


FR_PAT = r'(?<![A-Za-z])(?:UX-)?FR[-_ ]?[A-Z]{0,6}[-_ ]?\d{1,3}(?:\.\d{1,3})?\b'
NFR_PAT = r'\b(?:UX-)?NFR[-_ ]?[A-Z]{0,6}[-_ ]?\d{1,3}(?:\.\d{1,3})?\b'


def detect_mode(t):
    # The reliable signal is UX-prefixed requirement IDs: design PRDs use UX-FR-* / UX-NFR-*,
    # functional PRDs use FR-* / NFR-*. Generic markers (typography, WCAG, wireframe) also appear
    # in functional PRDs that carry a UI section, so they are NOT used to classify - only to hint.
    ux_ids = len(re.findall(r'\bux-n?fr[-_ ]?\d', t.lower()))
    return "design" if ux_ids >= 2 else "functional"


def analyse(t, mode="functional"):
    low = t.lower()
    lines = t.split('\n')
    cats, findings = [], []

    def add(level, msg, ref=""):
        findings.append({"level": level, "msg": msg, "ref": ref})

    def count(pat):
        return len(re.findall(pat, t, re.I))

    def has_section(pat):
        rx = re.compile("(" + pat + ")", re.I)
        for l in lines:
            s = l.strip()
            if re.match(r'^(#{1,6}\s|\d+[.\)]\s|\*\*|[A-Z].{0,40}:$)', s) or len(s) < 70:
                if rx.search(s):
                    return True
        return bool(rx.search(t))

    # ---- 1. Structure & anatomy (20) ----
    ac_entry = (("Definition of done / metrics",
                 "definition of done|done when|the standard|success metric|design metric|state.*complet")
                if mode == "design" else
                ("Acceptance criteria", "acceptance criteria|scenario|gherkin|given .*when"))
    core = [
        ("Summary", "summary|overview|executive summary"),
        ("Problem / users", "problem|background|users|persona|audience"),
        ("Goals", "goals|objectives"),
        ("Non-goals", "non-?goals|out of scope|won'?t have|not building"),
        ("Success metrics", "success metric|metrics|kpi|measures of success"),
        ("Functional requirements", "functional requirement|requirements|features|capabilit|screen requirement"),
        ac_entry,
        ("Non-functional reqs", "non-?functional|nfr|performance|reliability|quality attribute|accessibility"),
        ("Decisions / questions", "decision|open question|resolved|trade-?off|dependenc"),
        ("Risks", "risk|assumption|mitigation"),
    ]
    ctx = [
        ("Data / auth model", "data model|schema|authoris|authoriz|permission|rls|roles"),
        ("Information architecture", "information architecture|routes|screens|sitemap|navigation"),
        ("Domain / compliance", "gdpr|hipaa|pci|compliance|dpia|safeguard|residency"),
        ("Glossary", "glossary|definitions|terminology"),
    ]
    missing = [n for n, p in core if not has_section(p)]
    core_found = len(core) - len(missing)
    ctx_found = sum(1 for n, p in ctx if has_section(p))
    s_score = min(20, core_found * 2 + ctx_found * 0.5)
    if missing:
        add("fail" if len(missing) >= 4 else "warn", "Missing sections: " + ", ".join(missing) + ".", "§4")
    else:
        add("pass", "All core sections present.", "§4")
    if ctx_found:
        add("pass", f"{ctx_found} context section(s) present.", "§4")
    cats.append({"name": "Structure & anatomy", "score": s_score, "max": 20})

    # ---- 2. Requirement quality (22) ----
    fr = set(x.upper().replace(' ', '-').replace('_', '-') for x in re.findall(FR_PAT, t))
    nfr = set(re.findall(NFR_PAT, t, re.I))
    fr_count = len(fr)
    rq = 0
    if fr_count:
        rq += 8
        add("pass", f"{fr_count} functional-requirement ID(s) detected.", "§5")
    else:
        add("fail", "No functional-requirement IDs (e.g. FR-AUTH-1). Requirements need stable, citable IDs.", "§2·§5")
    moscow = bool(re.search(r"\b(must|should|could|won'?t)\b", t, re.I)) and bool(re.search(r"\b(must|should|could)\b", t, re.I))
    tiers = bool(re.search(r'\b(mvp|mlp|beyond|must-have|nice-to-have|phase\s*\d)\b', t, re.I))
    pricols = bool(re.search(r'\|\s*(pri|priority|moscow|tier)\s*\|', t, re.I))
    if moscow or tiers or pricols:
        rq += 6
        add("pass", "Priorities present (MoSCoW, tiers or explicit phasing).", "§5")
    else:
        add("warn", "No priority scheme detected (MoSCoW: Must/Should/Could/Won't, or MVP/MLP/Beyond).", "§5")
    if nfr:
        rq += 4
    techwords = ["postgres", "mysql", "mongodb", "redis", "kafka", "jwt", "oauth token", "react", "angular", "vue",
                 "kubernetes", "docker", "lambda", "s3 bucket", "dynamodb", "graphql resolver", "websocket", "grpc"]
    leak = []
    for l in lines:
        if re.search(r'\b(fr[-_ ]?\w*\d|shall|must|the system (will|shall|should))\b', l, re.I):
            for w in techwords:
                if w in l.lower() and w not in leak:
                    leak.append(w)
    rq += 4 - min(4, len(leak))
    if leak:
        add("warn", "Possible implementation leakage in requirements: " + ", ".join(leak[:5]) +
            ". State the capability, not the mechanism.", "§2·§5")
    cats.append({"name": "Requirement quality", "score": min(22, rq), "max": 22})

    # ---- 3. Testability (16) ----
    given, when, then = count(r'\bgiven\b'), count(r'\bwhen\b'), count(r'\bthen\b')
    scen = count(r'\bscenario\s*:')
    gherkin = min(given, when, then)
    ts = 0
    if mode == "design":
        states = sum(1 for s in ["empty", "loading", "error", "offline"] if re.search(r'\b' + s + r'\b', low))
        dod = bool(re.search(r'definition of done|done when|the standard|state.*complet|success metric|design metric', low))
        checkable = count(r'(100\s?%|\b0 [a-z]|wcag|\bAA\b|reduced motion|lint-?enforced|44|48)')
        if dod or gherkin or states >= 3:
            ts += 6
        ts += min(10, checkable + scen + gherkin)
        if ts > 0:
            add("pass" if ts >= 12 else "warn",
                f"Verifies via definition-of-done + {checkable} checkable design criteria "
                f"(states, AA, token compliance){' - broaden the metrics' if ts < 12 else ''}.", "§6")
        else:
            add("fail", "No definition-of-done, design metrics or acceptance criteria found.", "§6")
    else:
        if scen or gherkin:
            ts += 6
            units = max(scen, gherkin)
            ratio = units / (fr_count * 0.5) if fr_count else 1
            ts += round(min(1, ratio) * 10)
            add("pass" if ratio >= 0.6 else "warn",
                f"{units} acceptance scenario(s) for {fr_count or '?'} requirements" +
                (" - thin coverage, add the edge cases." if ratio < 0.6 else "."), "§6")
        else:
            add("fail", "No acceptance criteria found. Add Given / When / Then scenarios, including the awkward cases.", "§6")
    cats.append({"name": "Testability (acceptance criteria)" if mode != "design" else "Testability (definition-of-done)",
                 "score": min(16, ts), "max": 16})

    # ---- 4. Measurable NFRs (12) ----
    ns = 0
    if mode == "design":
        has_nfr = has_section("non-?functional|nfr|accessibility|wcag|a11y")
        measured = count(r'(wcag|\bAA\b|44|48|reduced motion|dynamic type|contrast|100\s?%|0 hardcoded|lint-?enforced|px\b)')
        if has_nfr:
            ns += 4
            ns += min(8, measured)
            add("pass" if measured >= 3 else "warn",
                f"{measured} measurable accessibility/token target(s) detected.", "§7")
        else:
            add("warn", "No non-functional / accessibility requirements found.", "§7")
        nfr_name = "Measurable NFRs (a11y/tokens)"
    else:
        if has_section("non-?functional|nfr|performance|latency|uptime|throughput"):
            ns += 4
            measured = count(r'\b\d[\d.,]*\s?(ms|s\b|sec|seconds|%|kb|mb|gb|rps|req/s|fps|p95|p99|users|concurrent|hours?|days?|minutes?)')
            ns += min(8, measured)
            add("pass" if measured >= 3 else "warn",
                f"{measured} measurable target(s) (number + unit) detected in the doc.", "§7")
        else:
            add("warn", "No non-functional requirements found. Add measurable targets for performance, security, accessibility.", "§7")
        nfr_name = "Measurable NFRs"
    cats.append({"name": nfr_name, "score": min(12, ns), "max": 12})

    # ---- 5. Decisions & governance (18) ----
    gs = 0
    if re.search(r'\bversion\b', t, re.I) and re.search(r'\b(status|owner|author|date)\b', t, re.I):
        gs += 4
        add("pass", "Document control / version header present.", "§11")
    else:
        add("warn", "No version/document-control header (Version, Status, Owner, Date).", "§11")
    if re.search(r'\bdecision\b', t, re.I):
        gs += 8
        add("pass", "Decision record(s) present.", "§10")
    else:
        add("warn", "No recorded decisions. Capture choices with their rationale and trade-off.", "§10")
    if re.search(r'open question|open decision|to be decided|\btbd\b|unresolved|dependenc', t, re.I):
        gs += 2
    if re.search(r'\brisk\b', t, re.I) and re.search(r'\b(mitigat\w*|likelihood|impact)\b', t, re.I):
        gs += 4
        add("pass", "Risks with mitigations present.", "§12")
    else:
        add("warn", "No risk table with mitigations.", "§12")
    cats.append({"name": "Decisions & governance", "score": min(18, gs), "max": 18})

    # ---- 6. Anti-pattern cleanliness (12, deductions) ----
    subj = ["easy to use", "user-?friendly", "intuitive", "seamless", "hassle-free", "state-of-the-art",
            "cutting-edge", "world-class", "best-in-class", "delightful", "blazing", "lightning[- ]fast",
            "snappy", "robust", "performant", "powerful", "modern", "clean ui", "nice ui"]
    risky = ["fast", "scalable", "secure", "reliable", "flexible", "simple"]
    vague = ["multiple", "several", "various", "numerous", "a number of", "a few", "some", "many",
             "and so on", r"etc\.", "and more"]
    filler = ["in order to", "it is important to note", "it should be noted", "the system will allow users to",
              "the system shall allow", "be able to", "where appropriate", "as appropriate", "if possible", "as needed"]
    flagged = {}

    def scan(lst, label):
        n = 0
        for w in lst:
            m = re.findall(r'\b' + w + r'\b', low)
            if m:
                n += len(m)
                flagged.setdefault(label, [])
                cw = re.sub(r'\\.|\[.*?\]|\?|-\?', '', w)
                if cw not in flagged[label] and len(flagged[label]) < 6:
                    flagged[label].append(cw)
        return n

    n_subj = scan(subj, "subjective adjectives")
    n_risky = 0
    for w in risky:
        for m in re.finditer(r'\b' + w + r'\b', low):
            s = max(0, m.start() - 40)
            e = min(len(low), m.start() + 40)
            if not re.search(r'\d', low[s:e]):
                n_risky += 1
                flagged.setdefault("subjective adjectives", [])
                if w not in flagged["subjective adjectives"] and len(flagged["subjective adjectives"]) < 6:
                    flagged["subjective adjectives"].append(w)
    n_vague = scan(vague, "vague quantifiers")
    n_filler = scan(filler, "filler / weasel phrasing")
    total_ap = n_subj + n_risky + n_vague + n_filler
    a_score = max(0, 12 - min(12, total_ap))
    for k, v in flagged.items():
        eg = '", "'.join(x for x in v if x)
        add("fail" if total_ap >= 6 else "warn", k.capitalize() + " flagged" + (': "' + eg + '"' if eg else "") + ".", "§13")
    if total_ap == 0:
        add("pass", "No subjective adjectives, vague quantifiers or filler detected.", "§13")
    cats.append({"name": "Anti-pattern cleanliness", "score": a_score, "max": 12})

    total = round(sum(c["score"] for c in cats))
    words = len(re.findall(r'\S+', t))
    return {"total": total, "cats": cats, "findings": findings, "frCount": fr_count, "words": words, "mode": mode}


def grade(total):
    return "A" if total >= 90 else "B" if total >= 80 else "C" if total >= 70 else "D" if total >= 55 else "E"


def main():
    args = sys.argv[1:]
    mode = "auto"
    path = None
    i = 0
    while i < len(args):
        if args[i] == "--mode" and i + 1 < len(args):
            mode = args[i + 1]
            i += 2
        else:
            path = args[i]
            i += 1

    text = sys.stdin.read() if (path is None or path == '-') else open(path, encoding='utf-8').read()
    resolved = detect_mode(text) if mode == "auto" else mode
    r = analyse(text, resolved)
    r["grade"] = grade(r["total"])

    mode_note = f"{resolved}" + (" (auto-detected)" if mode == "auto" else "")
    print(f"PRD heuristic score: {r['total']}/100  (grade {r['grade']})   -   mode: {mode_note}   -   {r['words']} words, {r['frCount']} FR IDs")
    print("-" * 66)
    for c in r["cats"]:
        print(f"  {c['name']:<36} {round(c['score'],1):>5} / {c['max']}")
    for lvl in ("fail", "warn"):
        rows = [f for f in r["findings"] if f["level"] == lvl]
        if rows:
            print(f"  {lvl.upper()}:")
            for f in rows:
                print(f"    - {f['msg']} {f['ref']}")
    if resolved == "functional" and detect_mode(text) == "design":
        print("  NOTE: this looks like a design/UX PRD - try --mode design for a fairer score.")
    print("\n---JSON---")
    print(json.dumps(r, ensure_ascii=False))


if __name__ == "__main__":
    main()
