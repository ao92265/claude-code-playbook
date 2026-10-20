#!/usr/bin/env python3
"""Aggregate an evidence-backed human/assistant assessment; never infer semantic ratings."""
import argparse
import json
import sys
from pathlib import Path

CATEGORIES = [
    ('names', 'Names and expressed intent', 10),
    ('functions', 'Focused functions and explicit effects', 15),
    ('cohesion', 'Cohesion, encapsulation and change isolation', 15),
    ('simplicity', 'Duplication and design simplicity', 10),
    ('errors', 'Error handling and outcome clarity', 10),
    ('boundaries', 'Dependencies, construction and external boundaries', 10),
    ('tests', 'Test quality and safe change', 20),
    ('presentation', 'Comments, formatting and local readability', 5),
    ('concurrency', 'Concurrency and shared-state discipline', 5),
]


def require_text(value, label):
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f'{label} must be nonempty text')


def text_list(value, label):
    if not isinstance(value, list) or any(not isinstance(x, str) or not x.strip() for x in value):
        raise ValueError(f'{label} must be a list of nonempty strings')


def template():
    return dict(title='Codebase review', scope='Set repository/module and source roots',
                revision='Record commit and working-tree status, or unavailable',
                sampled=True, sample=['List inspected files/flows before rating'],
                exclusions=[], checks=['Not run'],
                summary='Assessment not yet performed', top_fixes=[],
                categories=[dict(id=key, rating='unknown', confidence='low',
                                 reason='Not yet inspected', evidence=[])
                            for key, _, _ in CATEGORIES])


def aggregate(data):
    if not isinstance(data, dict):
        raise ValueError('report must be an object')
    for field in ('title', 'scope', 'revision', 'summary'):
        require_text(data.get(field), field)
    if type(data.get('sampled')) is not bool:
        raise ValueError('sampled must be true or false')
    for field in ('sample', 'exclusions', 'checks'):
        text_list(data.get(field), field)
    if not data['sample']:
        raise ValueError('sample must describe what was inspected or provided')
    fixes = data.get('top_fixes')
    if not isinstance(fixes, list):
        raise ValueError('top_fixes must be a list')
    for fix in fixes:
        if not isinstance(fix, dict):
            raise ValueError('each fix must be an object')
        for field in ('location', 'change', 'benefit', 'verification'):
            require_text(fix.get(field), f'fix.{field}')
    entries = data.get('categories')
    if not isinstance(entries, list) or any(not isinstance(c, dict) for c in entries):
        raise ValueError('categories must be a list of objects')
    ids = [c.get('id') for c in entries]
    expected = {key for key, _, _ in CATEGORIES}
    if len(ids) != len(expected) or any(not isinstance(x, str) for x in ids) or set(ids) != expected:
        raise ValueError('include each of the nine category IDs exactly once')
    by_id = {c['id']: c for c in entries}
    assessed = unknown = na = 0
    points = 0.0
    rows = []
    confidence = []
    for key, name, weight in CATEGORIES:
        row = dict(by_id[key])
        rating = row.get('rating')
        numeric = type(rating) is int and 0 <= rating <= 4
        if not numeric and rating not in ('unknown', 'na'):
            raise ValueError(f'{key}: rating must be an integer 0–4, unknown, or na')
        require_text(row.get('reason'), f'{key}.reason')
        if row.get('confidence') not in ('low', 'medium', 'high'):
            raise ValueError(f'{key}: confidence must be low, medium, or high')
        text_list(row.get('evidence'), f'{key}.evidence')
        if (numeric or rating == 'na') and not row['evidence']:
            raise ValueError(f'{key}: rated and NA categories require evidence')
        earned = weight * rating / 4 if numeric else None
        if numeric:
            assessed += weight
            points += earned
            confidence.append(row['confidence'])
        elif rating == 'unknown':
            unknown += weight
        else:
            na += weight
        row.update(name=name, weight=weight, points=earned)
        rows.append(row)
    applicable = assessed + unknown
    coverage = assessed / applicable if applicable else 0
    score = round(100 * points / assessed, 1) if assessed and coverage >= .7 else None
    grade = next((g for cutoff, g in [(90, 'A'), (80, 'B'), (70, 'C'), (55, 'D'), (0, 'E')]
                  if score is not None and score >= cutoff), None)
    result = dict(data)
    result.update(rubric_version='1.0', categories=rows, computed=dict(
        score=score, grade=grade, assessed_weight=assessed, unknown_weight=unknown,
        na_weight=na, applicable_weight=applicable, raw_points=points,
        coverage_percent=round(100 * coverage, 1),
        possible_range=[round(100 * points / applicable, 1),
                        round(100 * (points + unknown) / applicable, 1)] if applicable else None,
        provisional=bool(unknown or data['sampled']),
        confidence=min(confidence, key=['low', 'medium', 'high'].index) if confidence else 'unassessed'))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', nargs='?', help='Assessment JSON, or - for stdin')
    parser.add_argument('--template', action='store_true', help='Print an unassessed input template')
    parser.add_argument('--output', type=Path, help='Write scored JSON instead of stdout')
    args = parser.parse_args()
    try:
        if args.template:
            result = template()
        elif args.input:
            raw = sys.stdin.read() if args.input == '-' else Path(args.input).read_text()
            result = aggregate(json.loads(raw))
        else:
            parser.error('provide input or --template')
        output = json.dumps(result, indent=2, ensure_ascii=False, allow_nan=False) + '\n'
        if args.output:
            args.output.write_text(output)
        else:
            print(output, end='')
    except (ValueError, OSError) as exc:
        parser.exit(2, f'Error: {exc}\n')


if __name__ == '__main__':
    main()
