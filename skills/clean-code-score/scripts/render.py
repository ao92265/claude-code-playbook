#!/usr/bin/env python3
"""Render assessment JSON as a self-contained HTML scorecard; recompute all scores."""
import argparse
import html
import json
from pathlib import Path
from score import aggregate


def esc(value):
    return html.escape(str(value), quote=True)


def items(values):
    return '<ul>' + ''.join('<li>' + esc(v) + '</li>' for v in values) + '</ul>'


def render(data):
    data = aggregate(data)
    c = data['computed']
    headline = 'Insufficient evidence' if c['score'] is None else f"{c['score']:.1f}/100 · Grade {c['grade']}"
    status = 'Provisional' if c['provisional'] else 'Assessed scope'
    if data['sampled']:
        status += ' · Sampled review'
    interval = c['possible_range']
    range_text = f'{interval[0]:.1f}–{interval[1]:.1f}' if interval else 'Not applicable'
    rows = []
    for row in data['categories']:
        rating = row['rating']
        points = f"{row['points']:g}/{row['weight']}" if row['points'] is not None else '—'
        bar = f'<progress max="4" value="{rating}"></progress>' if type(rating) is int else ''
        rows.append(f'<tr><td><b>{esc(row["name"])}</b><br>{bar}</td>'
                    f'<td>{esc(row["weight"])}</td><td>{esc(rating)}</td><td>{points}</td>'
                    f'<td>{esc(row["confidence"])}</td><td>{esc(row["reason"])}{items(row["evidence"])}</td></tr>')
    fixes = ''.join(f'<li><b>{esc(f["change"])}</b><p>{esc(f["location"])}</p>'
                    f'<p>Benefit: {esc(f["benefit"])}</p><p>Verify: {esc(f["verification"])}</p></li>'
                    for f in data['top_fixes'])
    return f'''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{esc(data['title'])} — Clean Code score</title>
<style>
:root{{color-scheme:light dark;font:16px/1.55 system-ui,sans-serif}}
body{{max-width:1100px;margin:auto;padding:28px;background:light-dark(#f7f8fb,#15191f);color:light-dark(#172238,#e5edf8)}}
section{{background:light-dark(white,#202630);padding:24px;margin:20px 0;border-radius:12px}}
h1,h2,p{{margin-top:0}} .score{{font-size:2rem;font-weight:750;margin:10px 0}}
.meta{{opacity:.8}} .scroll{{overflow-x:auto}}table{{border-collapse:collapse;width:100%;font-size:.9rem}}
th,td{{text-align:left;vertical-align:top;padding:12px;border-bottom:1px solid #8885}}
th{{white-space:nowrap}}td:last-child{{min-width:260px}}progress{{max-width:160px;width:100%;accent-color:#4c89bf}}
li{{margin:7px 0;overflow-wrap:anywhere}}li p{{margin:4px 0}} code{{overflow-wrap:anywhere}}
@media print{{body{{background:white;color:black}} section{{break-inside:avoid}}}}
</style>
<header><h1>{esc(data['title'])}</h1><p class="meta">Clean Code alignment · Rubric {esc(data['rubric_version'])}</p></header>
<section><div class="score">{headline}</div><p>{status} · Evidence confidence: {esc(c['confidence'])}</p>
<p>Assessed weight: {c['assessed_weight']}/{c['applicable_weight']} ({c['coverage_percent']}%).
Unknown weight: {c['unknown_weight']}. Non-applicable weight: {c['na_weight']}.</p>
<p>Possible score across all applicable categories: {range_text}.
This range represents unknown ratings, not statistical confidence.</p>
<p class="meta">Category coverage measures assessed rubric weight, not the percentage of repository files inspected.</p></section>
<section><h2>Reasoning summary</h2><p>{esc(data['summary'])}</p></section>
<section><h2>Category assessment</h2><div class="scroll"><table><thead><tr><th>Category</th><th>Weight</th><th>Rating /4</th><th>Raw points</th><th>Confidence</th><th>Reason and evidence</th></tr></thead><tbody>{''.join(rows)}</tbody></table></div></section>
<section><h2>Priority improvements</h2><ol>{fixes}</ol>{'' if fixes else '<p>No supported improvements recorded.</p>'}</section>
<section><h2>Scope and evidence</h2><p>{esc(data['scope'])}</p><p>Revision: {esc(data['revision'])}</p>
<h3>Inspected files and flows</h3>{items(data['sample'])}<h3>Exclusions and limitations</h3>{items(data['exclusions'])}
<h3>Checks actually run</h3>{items(data['checks'])}</section>
<footer>Alignment with an adapted Clean Code rubric. Scores do not certify correctness, security or production readiness.
Weights and bands are skill design choices, not the book author's scoring system.</footer></html>'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    try:
        args.output.write_text(render(json.loads(args.input.read_text())))
        print(args.output)
    except (ValueError, OSError) as exc:
        parser.exit(2, f'Error: {exc}\n')


if __name__ == '__main__':
    main()
