#!/usr/bin/env python3
"""Deterministically aggregate the local Claude Code corpus (all logins) into two files:
   - quant.json  : quantitative rollups from ALL session-meta
   - facets_compact.json : trimmed qualitative facets for the narrative agent
Read-only over ~/.claude/usage-data."""
import json, glob, os, collections, re, sys

UD = os.path.expanduser(os.environ.get("CLAUDE_CONFIG_DIR", "~/.claude") + "/usage-data")
SM = glob.glob(os.path.join(UD, "session-meta", "*.json"))
FC = glob.glob(os.path.join(UD, "facets", "*.json"))
# locally harvested meta (harvest_local.py) for sessions the official pipeline missed;
# official session-meta wins on duplicate session id
LM = glob.glob(os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "local-meta", "*.json"))
_official_ids = set(map(os.path.basename, SM))
SM += sorted(f for f in LM if os.path.basename(f) not in _official_ids)
# locally harvested facets (facet filenames are session ids); official facets win on duplicates
LF = glob.glob(os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "local-facets", "*.json"))
_official_facet_ids = set(map(os.path.basename, FC))
FC += sorted(f for f in LF if os.path.basename(f) not in _official_facet_ids)
OUT = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)

def load(f):
    try: return json.load(open(f))
    except: return None

# ---------- quantitative ----------
q = dict(sessions=0, input_tokens=0, output_tokens=0, commits=0, pushes=0, commit_sessions=0, commit_sessions_unpushed=0,
         user_msgs=0, asst_msgs=0, total_minutes=0.0, tool_errors=0, tool_errors_real=0, tool_errors_real_sessions=0,
         task_agent_sessions=0, mcp_sessions=0, websearch_sessions=0)
tools = collections.Counter()
langs = collections.Counter()
errcats = collections.Counter()
byday = collections.Counter()
byhour = collections.Counter()
projarea = collections.Counter()
durations = []
tok_per_session = []
first_prompts = []
lines_added = lines_removed = 0
# interactive-only rates: headless SDK runs (scripted batches) dilute per-session rates
# records harvested before the split have no "headless" key (transcript since deleted):
# counted as unknown and left out of the rates rather than guessed
inter = dict(sessions=0, headless_sessions=0, unknown_mode_sessions=0, worktree_sessions=0, task_agent_sessions=0)
inter_durations = []
headless_by_area = collections.Counter()

def area_of(path):
    if not path: return "other"
    p = path.lower()
    # collapse to a coarse area from the project path
    # NOTE: the scratch/worktree test must run BEFORE the /repos/ test. Worktrees now live at
    # ~/Repos/.agent-worktrees/<id>, so /repos/ matched first and bucketed them as a repo named
    # ".agent-worktrees" — leaving scratch/worktree absent and Isolation discipline scoring 0.
    # Claude Code's native worktrees sit at <repo>/.claude/worktrees/<name> and would
    # otherwise bucket as their parent repo.
    if ("scratchpad" in p or "/tmp/" in p or "agent-worktrees" in p
            or "/.claude/worktrees/" in p): return "scratch/worktree"
    if "/repos/" in p:
        m = re.search(r"/repos/([^/]+)", p);
        if m: return m.group(1)[:28]
    _home = os.path.expanduser("~").rstrip("/")
    if p.endswith(_home.replace("/", "-").lower()) or p.rstrip("/").endswith(os.path.basename(_home).lower()): return "home (~)"
    m = re.search(r"([^/]+)/?$", path.rstrip("/"))
    return (m.group(1)[:28] if m else "other")

for f in SM:
    d = load(f)
    if not d: continue
    q["sessions"] += 1
    q["input_tokens"] += d.get("input_tokens", 0) or 0
    q["output_tokens"] += d.get("output_tokens", 0) or 0
    q["commits"] += d.get("git_commits", 0) or 0
    q["pushes"] += d.get("git_pushes", 0) or 0
    # interactive only, like isolation and delegation: headless pipelines commit locally on purpose
    if d.get("ended_unpushed") is not None and d.get("headless") is False:
        q["commit_sessions"] += 1
        q["commit_sessions_unpushed"] += 1 if d["ended_unpushed"] else 0
    q["user_msgs"] += d.get("user_message_count", 0) or 0
    q["asst_msgs"] += d.get("assistant_message_count", 0) or 0
    mins = d.get("duration_minutes", 0) or 0
    q["total_minutes"] += mins
    if mins: durations.append(mins)
    q["tool_errors"] += d.get("tool_errors", 0) or 0
    q["tool_errors_real"] += d.get("tool_errors_real", d.get("tool_errors", 0)) or 0
    if "tool_errors_real" in d: q["tool_errors_real_sessions"] += 1
    if d.get("uses_task_agent"): q["task_agent_sessions"] += 1
    if d.get("uses_mcp"): q["mcp_sessions"] += 1
    if d.get("uses_web_search"): q["websearch_sessions"] += 1
    lines_added += d.get("lines_added", 0) or 0
    lines_removed += d.get("lines_removed", 0) or 0
    for k, v in (d.get("tool_counts") or {}).items(): tools[k] += v
    for k, v in (d.get("languages") or {}).items(): langs[k] += v
    for k, v in (d.get("tool_error_categories") or {}).items(): errcats[k] += v
    st = d.get("start_time") or ""
    if st[:10]: byday[st[:10]] += 1
    for h in (d.get("message_hours") or []):
        try: byhour[int(h)] += 1
        except: pass
    area = area_of(d.get("project_path", ""))
    projarea[area] += 1
    if "headless" not in d:
        inter["unknown_mode_sessions"] += 1
    elif d["headless"]:
        inter["headless_sessions"] += 1
        headless_by_area[area] += 1
    else:
        inter["sessions"] += 1
        if area == "scratch/worktree" or any(area_of(c) == "scratch/worktree" for c in d.get("cwds") or []):
            inter["worktree_sessions"] += 1
        if d.get("uses_task_agent"): inter["task_agent_sessions"] += 1
        if mins: inter_durations.append(mins)
    ot = d.get("output_tokens", 0) or 0
    if ot: tok_per_session.append(ot)
    fp = d.get("first_prompt")
    if fp: first_prompts.append(fp[:160])

durations.sort(); tok_per_session.sort()
def med(a): return a[len(a)//2] if a else 0
q["total_hours"] = round(q["total_minutes"]/60)
q["median_session_min"] = round(med(durations), 1)
q["median_output_tokens"] = med(tok_per_session)
q["active_days"] = len(byday)
q["lines_added"] = lines_added
q["lines_removed"] = lines_removed
inter_durations.sort()
inter["median_session_min"] = round(med(inter_durations), 1)
inter["headless_top_areas"] = headless_by_area.most_common(5)
q["interactive"] = inter
q["top_tools"] = tools.most_common(12)
q["top_languages"] = langs.most_common(10)
q["error_categories"] = errcats.most_common(10)
q["by_hour"] = [[h, byhour.get(h, 0)] for h in range(24)]
q["top_project_areas"] = projarea.most_common(15)
q["busiest_days"] = sorted(byday.items(), key=lambda x:-x[1])[:10]
q["facet_count"] = len(FC)

json.dump(q, open(os.path.join(OUT, "quant.json"), "w"), indent=2)

# ---------- qualitative (compact) + distributions ----------
compact = []
outc = collections.Counter(); fric = collections.Counter()
gcat = collections.Counter(); psucc = collections.Counter()
# collapse near-duplicate goal categories to a canonical taxonomy
GCAT_MAP = {"code_review_audit":"code_review","code_review_merge":"code_review","code_review_and_merge":"code_review",
            "bug_fix":"bug_fixing","bug_fixing":"bug_fixing","debugging":"debugging",
            "documentation":"documentation","warmup_minimal":"warmup/trivial"}
for f in FC:
    d = load(f)
    if not d: continue
    fr = list((d.get("friction_counts") or {}).keys())
    gc = list((d.get("goal_categories") or {}).keys())
    compact.append(dict(
        goal=(d.get("underlying_goal") or "")[:200],
        outcome=d.get("outcome"),
        primary_success=d.get("primary_success"),
        frictions=fr,
        goal_categories=gc,
        summary=(d.get("brief_summary") or "")[:280],
    ))
    if d.get("outcome"): outc[d["outcome"]] += 1
    for k in fr: fric[k] += 1
    for k in gc: gcat[GCAT_MAP.get(k, k)] += 1
    if d.get("primary_success"): psucc[d["primary_success"]] += 1
json.dump(compact, open(os.path.join(OUT, "facets_compact.json"), "w"), indent=2)

# fold facet distributions + raw-transcript count into quant.json (tiered coverage)
q["facet_n"] = len(compact)
q["facet_outcomes"] = outc.most_common()
q["facet_frictions"] = fric.most_common(8)
q["facet_goalcats"] = gcat.most_common(10)
q["facet_primary_success"] = psucc.most_common(8)
q["raw_transcripts"] = len(glob.glob(os.path.join(os.path.dirname(UD), "projects", "**", "*.jsonl"), recursive=True))
json.dump(q, open(os.path.join(OUT, "quant.json"), "w"), indent=2)  # rewrite with additions

print("quant.json sessions=%d hours=%d tools=%d langs=%d areas=%d" % (
    q["sessions"], q["total_hours"], len(q["top_tools"]), len(q["top_languages"]), len(q["top_project_areas"])))
print("facets_compact.json entries=%d" % len(compact))
print("top areas:", q["top_project_areas"][:6])
print("top tools:", q["top_tools"][:6])
