#!/usr/bin/env python3
"""Inject diagrams and tables into a PLAN.md, producing the enhanced markdown
that the markdown converter then turns into body.html.

Usage: inject.py <config.json> <plan.md> <out.md>

The plan is written as plain prose. Some passages read better as a picture or a
table than as a sentence: a lineage chain, a vocabulary list, an architecture
sketch. Rather than authoring those as HTML inside the markdown, the writer
leaves the prose alone and this script swaps each passage for a mermaid fence or
a table at build time. The prose stays reviewable and the diagrams stay in
version control as text.

Every replacement must match exactly once. A plan gets edited between builds, and
a silently skipped diagram is far worse than a failed build: the reader would get
a paragraph where a picture should be and nobody would notice. So a miss is fatal.

No mermaid init directive is emitted here. assemble.py renders these fences to
inline SVG itself and paints them from the page's CSS tokens, so a palette baked
in at this stage would only fight it. Templates may still carry a
{MERMAID_INIT} placeholder for readability; it is stripped before writing.
"""
import json
import pathlib
import sys


def die(msg):
    sys.exit(f"INJECT FAIL: {msg}")


def main():
    if len(sys.argv) != 4:
        die("usage: inject.py <config.json> <plan.md> <out.md>")

    cfg_path, src_path, out_path = (pathlib.Path(p) for p in sys.argv[1:4])

    for p, what in ((cfg_path, "config"), (src_path, "plan markdown")):
        if not p.is_file():
            die(f"{what} not found: {p}")

    try:
        cfg = json.loads(cfg_path.read_text())
    except json.JSONDecodeError as e:
        die(f"config is not valid JSON: {e}")

    replacements = cfg.get("inject", {}).get("replacements")
    if replacements is None:
        die("config has no inject.replacements list")

    md = src_path.read_text()

    for i, r in enumerate(replacements):
        label = r.get("label", f"replacement {i}")
        find = r.get("find")
        if not find:
            die(f"{label}: no 'find' string")

        # Replacement bodies are usually multi-line mermaid, which is painful to
        # read escaped inside JSON. Either form is accepted: inline for a short
        # swap, a sibling file for a diagram worth editing on its own.
        if "replace_file" in r:
            rf = cfg_path.parent / r["replace_file"]
            if not rf.is_file():
                die(f"{label}: replacement file not found: {rf}")
            new = rf.read_text().rstrip("\n")
        elif "replace" in r:
            new = r["replace"]
        else:
            die(f"{label}: needs either 'replace' or 'replace_file'")

        # An anchor that appears twice is as broken as one that appears zero
        # times: we would not know which passage the author meant.
        n = md.count(find)
        if n != 1:
            die(f"{label}: anchor found {n} times, expected exactly 1")

        # Some anchors are a sentence the diagram should follow rather than
        # replace. Setting "keep_anchor" puts it back in front of the new block.
        if r.get("keep_anchor"):
            new = find + "\n\n" + new

        md = md.replace(find, new)

    md = md.replace("{MERMAID_INIT}\n", "")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(md)
    print(f"OK {len(replacements)} replacements, {len(md)} chars -> {out_path}")


if __name__ == "__main__":
    main()
