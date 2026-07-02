#!/usr/bin/env python3
"""scorecard.py — the deterministic 9-factor myinsights scorecard as an importable module.

Extracted verbatim from render_myinsights.py so the renderer, the scores.json exporter,
and any future leaderboard client share ONE formula. Two variants:

- variant="report"  (FORMULA_VERSION_REPORT): bit-identical to the pre-refactor renderer.
  push_through is unclamped (can exceed 100 if pushes > commits) and tool_reliability can
  go negative if errors exceed counted calls — kept so local report numbers never shift
  without a formula_version bump.
- variant="export"  (FORMULA_VERSION_EXPORT): every factor clamped to [0, 100]. This is
  the leaderboard/wire formula; scores.json uses it.

Pure function of quant.json's dict — no I/O, no network, no globals.
"""

SCHEMA_VERSION = 1
FORMULA_VERSION_REPORT = "1.0"
FORMULA_VERSION_EXPORT = "1.0-clamped"

# Grade band colors (Linear design tokens, shared with the renderer)
_GREEN, _BLUE, _YELLOW, _RED = "#27A644", "#4EA7FC", "#F0BF00", "#EB5757"


def _fmt(x):
    return f"{x:,}" if isinstance(x, int) else x


def compute_scores(q, variant="report"):
    """Return (factors, composite). factors = list of dicts sorted best-first, each
    {name, score, kind ('full'|'samp'), w (weight %), ev (evidence), lever (how to raise)}.
    composite = weighted mean 0-100."""
    n_facet = max(q.get("facet_n", q.get("facet_count", 0)), 1)
    n_full = max(q.get("sessions", 0), 1)
    outc = dict(q.get("facet_outcomes", []))
    fric = dict(q.get("facet_frictions", []))
    areas = q.get("top_project_areas", [])
    landed = outc.get("fully_achieved", 0) + outc.get("mostly_achieved", 0)
    unclear = outc.get("unclear_from_transcript", 0)
    buggy = fric.get("buggy_code", 0)
    wrong = fric.get("wrong_approach", 0)
    commits = q.get("commits", 0)
    pushes = q.get("pushes", 0)
    days = max(q.get("active_days", 1), 1)
    cadence = commits / days
    worktree = next((v for nm, v in areas if nm == "scratch/worktree"), 0)
    agents = q.get("task_agent_sessions", 0)
    errs = q.get("tool_errors", 0)
    top_calls = sum(v for _, v in q.get("top_tools", [])) or 1

    F = []
    F.append(dict(name="Ship cadence", score=min(100.0, 100 * cadence / 25), kind="full", w=10,
        ev=f"{_fmt(commits)} commits over {days} active days ≈ {cadence:.0f}/day, scored vs a 25/day target",
        lever="Already elite — protect it; don't let review debt slow the pipeline."))
    F.append(dict(name="Tool reliability", score=100 * (1 - errs / top_calls), kind="full", w=5,
        ev=f"{_fmt(errs)} tool errors vs {_fmt(top_calls)} top-12 tool calls (error rate is an upper bound — denominator excludes long-tail tools)",
        lever="Mostly environmental; pre-flight known blockers (ports, auth, dead servers)."))
    F.append(dict(name="Survival rate", score=100 * (1 - unclear / n_facet), kind="samp", w=10,
        ev=f"{unclear} of {n_facet} analyzed sessions died to output-token-limit errors",
        lever="Budgeted runs with a forced reboot handoff before the ceiling."))
    F.append(dict(name="Landing rate", score=100 * landed / n_facet, kind="samp", w=20,
        ev=f"{landed} of {n_facet} analyzed sessions ended fully or mostly achieved",
        lever="Tighten done-criteria up front; keep the verify gate mandatory."))
    F.append(dict(name="Approach accuracy", score=100 * (1 - wrong / n_facet), kind="samp", w=15,
        ev=f"wrong_approach flagged in {wrong} of {n_facet} analyzed sessions",
        lever="5-minute feasibility probe + named fallback before coding against external systems."))
    F.append(dict(name="Isolation discipline", score=100 * worktree / n_full, kind="full", w=10,
        ev=f"{_fmt(worktree)} of {_fmt(n_full)} sessions ran in isolated scratch/worktree areas",
        lever="Default every multi-file build into a worktree off origin/main."))
    F.append(dict(name="Clean first pass", score=100 * (1 - buggy / n_facet), kind="samp", w=15,
        ev=f"buggy_code flagged in {buggy} of {n_facet} analyzed sessions",
        lever="Failing test (or assertion checklist) BEFORE editing 2+ files."))
    F.append(dict(name="Push-through", score=100 * pushes / max(commits, 1), kind="full", w=10,
        ev=f"{_fmt(pushes)} pushes vs {_fmt(commits)} commits — work that actually left the machine",
        lever="Land or discard: fewer stranded local commits — unpushed work is invisible to teammates and at risk on a single machine."))
    F.append(dict(name="Delegation leverage", score=min(100.0, 100 * (agents / n_full) / 0.20), kind="full", w=5,
        ev=f"{agents} of {_fmt(n_full)} sessions used task agents, scored vs a 20% target",
        lever="Route search/mechanical work to haiku/sonnet subagents; keep Opus for judgment."))

    if variant == "export":
        for f in F:
            f["score"] = max(0.0, min(100.0, f["score"]))

    total_w = sum(f["w"] for f in F)
    composite = sum(f["score"] * f["w"] for f in F) / total_w
    return sorted(F, key=lambda f: -f["score"]), composite


def grade_of(s):
    for cut, letter in ((93, "A+"), (85, "A"), (78, "A−"), (70, "B+"), (62, "B"), (55, "B−"), (45, "C+"), (35, "C")):
        if s >= cut:
            return letter
    return "D"


def grade_color(s):
    if s >= 78: return _GREEN
    if s >= 55: return _BLUE
    if s >= 35: return _YELLOW
    return _RED
