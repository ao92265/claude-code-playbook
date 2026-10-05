#!/usr/bin/env python3
"""Run the template's pre-circulation checklist against a summary markdown file.

Prints one PASS / FAIL / WARN line per check and exits 1 if any check FAILs.
It reads the markdown, not the .docx, so run it before building.

Usage: python3 check_summary.py summary.md
"""
import re
import sys

REQUIRED = ["Financial Summary", "Part 1", "Part 2", "Part 3", "Part 4", "Part 5", "Part 6",
            "Part 7", "Part 8", "Part 9", "Part 10", "Appendix"]
GUIDANCE_MARKERS = ["What goes here", "WHAT GOES HERE", "Sample (Project", "Sample rows",
                    "Sample note", "Sample cover block", "How to use this template",
                    "Pre-circulation checklist"]
SPELLING_PAIRS = [("organis", "organiz"), ("recognis", "recogniz"), ("prioritis", "prioritiz"),
                  ("optimis", "optimiz"), ("standardis", "standardiz"), ("behaviour", "behavior"),
                  ("colour", "color"), ("licence", "license"), ("analys", "analyz")]
WORDS_PER_PAGE = 550  # the template's density with tables, measured on project-d


def main(path):
    src = open(path, encoding="utf-8").read()
    body = src.split("\\newpage", 1)[-1]
    results = []

    def add(status, name, detail=""):
        results.append((status, name, detail))

    # 1. placeholders
    no_images = "\n".join(l for l in src.splitlines() if not l.strip().startswith("!["))
    ph = re.findall(r"\[[^\]\n]+\]", no_images)
    ph = [p for p in ph if p not in ("[x]", "[X]", "[ ]")]
    # later checks must not be satisfied by the wording inside a placeholder
    src = re.sub(r"\[[^\]\n]+\]", "", no_images)
    body = src.split("\\newpage", 1)[-1]
    add("FAIL" if ph else "PASS", "1. No [placeholders] left",
        "%d left: %s" % (len(ph), ", ".join(sorted(set(ph))[:8])) if ph else "")

    # 2. guidance and sample boxes
    g = [mk for mk in GUIDANCE_MARKERS if mk in src]
    if re.search(r"^>\s*\**\s*Sample\b", src, re.M | re.I):
        g.append("a '> Sample' box")
    add("FAIL" if g else "PASS", "2. Guidance and sample boxes deleted", ", ".join(g))

    # 3. blended rate stated and applied to both scenarios
    rate = re.search(r"per developer[- ]month", src, re.I)
    both = re.search(r"(applied to both|both scenarios)", src, re.I)
    add("PASS" if rate and both else "FAIL", "3. Blended rate stated and applied to both scenarios",
        "" if rate and both else ("rate missing" if not rate else "no 'applied to both scenarios' wording"))

    # 4. benchmark has a named source
    bm = re.search(r"(COCOMO|internal(ly)? benchmark|comparable|Request for Assistance|"
                   r"client'?s own estimate)", src, re.I)
    add("PASS" if bm else "FAIL", "4. Benchmark source named",
        "" if bm else "say COCOMO II, an internal benchmark, or the comparable project")

    # 5. delivery vs customer-side runtime cost
    rt = re.search(r"(operating cost|no runtime AI cost|no runtime (AI|inference) cost|calls no (language )?model)", src, re.I)
    add("PASS" if rt else "FAIL", "5. Delivery cost separated from runtime cost",
        "" if rt else "state runtime AI cost as a customer-side operating cost, or that there is none")

    # 6. repo figures carry a capture date
    cap = re.search(r"captured[^.\n]{0,80}\b(19|20)\d\d\b", src, re.I)
    add("PASS" if cap else "FAIL", "6. Repository figures carry a capture date")

    # 7. human review rate stated
    hr = re.search(r"human review[^.\n]{0,120}(\d+(\.\d+)?\s*(percent|%))|"
                   r"(\d+(\.\d+)?\s*(percent|%))[^.\n]{0,120}human review", src, re.I)
    add("PASS" if hr else "FAIL", "7. Human review rate on merged PRs stated")

    # 8. Part 10 remaining scope matches Part 2 completion
    comp = re.search(r"approximately (\d+) percent complete|completion is approximately (\d+) percent", src, re.I)
    p10 = re.split(r"^##\s+Part 10\b", src, maxsplit=1, flags=re.M)
    rem = re.search(r"remaining (\d+) percent", p10[1], re.I) if len(p10) == 2 else None
    if comp and rem:
        c = int(comp.group(1) or comp.group(2))
        r = int(rem.group(1))
        add("PASS" if c + r == 100 else "FAIL", "8. Part 10 matches Part 2 completion",
            "%d%% complete + %d%% remaining" % (c, r))
    else:
        add("FAIL", "8. Part 10 matches Part 2 completion",
            "need 'approximately N percent complete' in Part 2 and 'Remaining N percent' in Part 10")

    # extra: structure, failures reported, length, spelling, dashes
    missing = [s for s in REQUIRED if not re.search(r"^##\s+" + re.escape(s) + r"\b", body, re.M)]
    add("FAIL" if missing else "PASS", "Structure: all sections present", ", ".join(missing))

    p8 = body.split("Part 8", 1)[-1].split("Part 9", 1)[0] if "Part 8" in body else ""
    add("PASS" if re.search(r"\d", p8) and len(p8) > 600 else "WARN",
        "At least one failure reported with numbers (Part 8)")

    words = len(re.findall(r"\w+", body))
    pages = words / float(WORDS_PER_PAGE)
    add("PASS" if 10 <= pages <= 16 else "WARN", "Length 10 to 16 pages",
        "about %d words, roughly %.0f pages" % (words, pages))

    low = src.lower()
    mixed = [a + "/" + b for a, b in SPELLING_PAIRS if a in low and b in low]
    add("WARN" if mixed else "PASS", "One spelling convention", ", ".join(mixed))

    dashes = src.count("—") + src.count("–")
    add("WARN" if dashes else "PASS", "No em or en dashes", "%d found" % dashes if dashes else "")

    for st, name, detail in results:
        print("%-4s  %s%s" % (st, name, ("  (" + detail + ")") if detail else ""))
    fails = sum(1 for r in results if r[0] == "FAIL")
    print("\n%d FAIL, %d WARN" % (fails, sum(1 for r in results if r[0] == "WARN")))
    return 1 if fails else 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1]))
