#!/usr/bin/env python3
"""Score prose 0 to 5 for AI tells. Prints the score, exits 0 only at 5.

Each of five categories costs one point if it has any match. Fenced code
blocks and inline code are stripped before scoring. Usage:
  score.py FILE | score.py --text "..." | cat x | score.py -
  --allow-proof  report unsourced numbers but do not penalise them
Hook use: run on a draft, block when the exit code is non-zero.
"""
import re
import sys

FENCE = re.compile(r"(^|\n)[ \t]*(```|~~~).*?\n[ \t]*\2[^\n]*", re.S)
INLINE = re.compile(r"`[^`\n]*`")
DASH = re.compile("[—–]")
SMART = re.compile("[“”‘’]")
NOUNS = r"(?:users|customers|teams|clients|developers|companies|businesses|people|engineers|organi[sz]ations)"
PROOF = re.compile(
    r"\b\d[\d,.]*\s*(?:[kKmM]\+?|%|\+)?\s+(?:\w+\s+){0,2}" + NOUNS + r"\b", re.I)
SOURCED = re.compile(r"https?://|\bsource:|\bper [A-Z]|\[\d+\]|\(\w[^)]*\d{4}\)")

CATS = {
    "vocabulary": re.compile(
        r"\b(delve|seamless(?:ly)?|game-changing|revolutioni[sz]e|supercharge|"
        r"leverage|utili[sz]e|holistic|tapestry|testament|transformative|"
        r"unlock|elevate|empower|streamline|meticulous|intricate|"
        r"in today's fast-paced|rapidly evolving landscape)\b", re.I),
    "patterns": re.compile(
        r"(not just [^.]{1,60}, it(?:'?s| is)|not just [^.]{1,60}, but|"
        r"here'?s the (?:kicker|thing)|let'?s dive in|great question|"
        r"i hope this helps|let me know if you have any questions|"
        r"\bin conclusion\b|\bmoreover,|\bfurthermore,|\badditionally,)", re.I),
}


def strip_code(text):
    return INLINE.sub("", FENCE.sub("\n", text))


def score(text, allow_proof=False):
    t = strip_code(text)
    hits = {}
    for name, rx in CATS.items():
        m = rx.findall(t)
        if m:
            hits[name] = m
    if len(DASH.findall(t)) > 2 or len(SMART.findall(t)) > 0:
        hits["punctuation"] = ["dashes>2 or smart quotes"]
    proof = []
    for sent in re.split(r"(?<=[.!?])\s+|\n", t):
        for m in PROOF.finditer(sent):
            if not SOURCED.search(sent):
                proof.append(m.group(0))
    if proof:
        hits["unsourced_numbers"] = proof
    if not t.strip():
        hits["empty"] = ["no scorable text"]
    penal = [k for k in hits if not (allow_proof and k == "unsourced_numbers")]
    return max(0, 5 - len(penal)) if "empty" not in hits else 0, hits


def main(argv):
    allow = "--allow-proof" in argv
    argv = [a for a in argv if a != "--allow-proof"]
    if argv[:1] == ["--text"] and len(argv) > 1:
        text = argv[1]
    elif argv[:1] in ([], ["-"]):
        text = sys.stdin.read()
    else:
        with open(argv[0], encoding="utf-8") as f:
            text = f.read()
    s, hits = score(text, allow)
    for k, v in hits.items():
        print("  %s: %s" % (k, "; ".join(map(str, v[:5]))))
    print("score %d/5" % s)
    return 0 if s == 5 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
