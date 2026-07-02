#!/usr/bin/env python3
"""export_scores.py [quant.json] [out.json]
Export the myinsights scorecard as a machine-readable scores.json — the ONLY artifact
that may ever leave the machine (leaderboard wire format).

STRICT ALLOWLIST — the payload contains exactly:
  schema_version, formula_version, corpus{n_sessions, n_facets, active_days, as_of},
  factors[{name, score, kind, w}], composite, grade, skill_version
Nothing else. No evidence strings, no levers, no project areas, no by-hour/by-day data,
no tokens, no paths. Uses the clamped "export" formula variant (all scores in [0,100]).

Also maintains local snapshots under <skill>/data/snapshots/ so personal-best deltas
are computable offline: first run writes a baseline; later runs print the delta vs the
previous snapshot, then append a new one (one per day, same-day overwrites).

No network. Read-only over quant.json; writes only out.json + the snapshot dir.
"""
import json, os, sys, glob, subprocess, datetime

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from scorecard import compute_scores, grade_of, SCHEMA_VERSION, FORMULA_VERSION_EXPORT

SKILL_VERSION = "2026.07.02"
SNAP_DIR = os.path.join(HERE, "data", "snapshots")

def load_quant(path):
    if path and os.path.exists(path):
        return json.load(open(path))
    default = "/tmp/myinsights/quant.json"
    if os.path.exists(default):
        return json.load(open(default))
    # no quant available — build one (read-only scan, same as the skill's step 1)
    os.makedirs("/tmp/myinsights", exist_ok=True)
    subprocess.run([sys.executable, os.path.join(HERE, "gather_all.py"), "/tmp/myinsights"],
                   check=True, stdout=subprocess.DEVNULL)
    return json.load(open(default))

def build_payload(q):
    factors, composite = compute_scores(q, variant="export")
    return {
        "schema_version": SCHEMA_VERSION,
        "formula_version": FORMULA_VERSION_EXPORT,
        "corpus": {
            "n_sessions": q.get("sessions", 0),
            "n_facets": q.get("facet_n", q.get("facet_count", 0)),
            "active_days": q.get("active_days", 0),
            "as_of": datetime.date.today().isoformat(),
        },
        "factors": [{"name": f["name"], "score": round(f["score"], 1),
                     "kind": f["kind"], "w": f["w"]} for f in factors],
        "composite": round(composite, 1),
        "grade": grade_of(composite),
        "skill_version": SKILL_VERSION,
    }

def latest_snapshot():
    snaps = sorted(glob.glob(os.path.join(SNAP_DIR, "scores-*.json")))
    return json.load(open(snaps[-1])) if snaps else None

def print_delta(prev, cur):
    d = cur["composite"] - prev["composite"]
    print(f"Δ composite vs {prev['corpus']['as_of']}: {d:+.1f}  "
          f"({prev['composite']} → {cur['composite']}, grade {prev['grade']} → {cur['grade']})")
    prev_f = {f["name"]: f["score"] for f in prev["factors"]}
    moved = sorted(((f["name"], f["score"] - prev_f.get(f["name"], f["score"]))
                    for f in cur["factors"]), key=lambda x: -abs(x[1]))
    for name, df in moved[:3]:
        if abs(df) >= 0.05:
            print(f"  {name}: {df:+.1f}")

def main():
    quant_path = sys.argv[1] if len(sys.argv) > 1 else None
    out_path = sys.argv[2] if len(sys.argv) > 2 else "scores.json"
    q = load_quant(quant_path)
    payload = build_payload(q)

    prev = latest_snapshot()
    if prev:
        print_delta(prev, payload)
    else:
        print("baseline snapshot — deltas start from the next run")

    json.dump(payload, open(out_path, "w"), indent=2)
    os.makedirs(SNAP_DIR, exist_ok=True)
    snap = os.path.join(SNAP_DIR, f"scores-{payload['corpus']['as_of']}.json")
    json.dump(payload, open(snap, "w"), indent=2)
    print(f"wrote {out_path} (composite {payload['composite']} {payload['grade']}) · snapshot {os.path.basename(snap)}")

if __name__ == "__main__":
    main()
