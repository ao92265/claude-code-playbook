#!/usr/bin/env python3
"""Deterministically harvest session-meta for transcripts the official usage-data pipeline
missed (nothing ingested after 2026-07-02). Streams ~/.claude/projects/*/*.jsonl line-by-line,
filters on the INTERNAL first-record timestamp (mtimes unreliable after the 07-14 wipe), and
emits one JSON per session to data/local-meta/<sessionid>.json in the official session-meta
schema (deterministic fields only; no LLM-judged fields). Tagged "source":"local-harvest".
Read-only over ~/.claude/projects and ~/.claude/usage-data. Honours CLAUDE_CONFIG_DIR.
Usage: harvest_local.py [START_DATE [END_DATE]]   (YYYY-MM-DD, default 2026-07-03..today)"""
import json, glob, os, re, sys, collections, datetime

CFG = os.path.expanduser(os.environ.get("CLAUDE_CONFIG_DIR", "~/.claude"))
PROJ = os.path.join(CFG, "projects")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "local-meta")
START = sys.argv[1] if len(sys.argv) > 1 else "2026-07-03"
END = sys.argv[2] if len(sys.argv) > 2 else datetime.date.today().isoformat()

EXT_LANG = {".py": "Python", ".ts": "TypeScript", ".tsx": "TypeScript", ".js": "JavaScript",
            ".jsx": "JavaScript", ".mjs": "JavaScript", ".cjs": "JavaScript", ".md": "Markdown",
            ".json": "JSON", ".html": "HTML", ".htm": "HTML", ".css": "CSS", ".scss": "CSS",
            ".sh": "Shell", ".bash": "Shell", ".zsh": "Shell", ".yml": "YAML", ".yaml": "YAML"}

def parse_ts(ts):
    try: return datetime.datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except Exception: return None

def text_of(content):
    """First real user text from a message content (str or blocks); None if tool-result-only."""
    if isinstance(content, str):
        return content if content.strip() else None
    if isinstance(content, list):
        for b in content:
            if isinstance(b, dict) and b.get("type") == "text" and (b.get("text") or "").strip():
                return b["text"]
    return None

def err_category(tool, text):
    t = (text or "").lower()
    if "user doesn't want" in t or "user rejected" in t or "request was rejected" in t: return "User Rejected"
    if "no such file" in t or "does not exist" in t or "file not found" in t: return "File Not Found"
    if "string to replace not found" in t or "old_string" in t: return "Edit Failed"
    if "too large" in t or "exceeds maximum" in t: return "File Too Large"
    if "has been modified" in t or "file has changed" in t: return "File Changed"
    if tool == "Bash": return "Command Failed"
    return "Other"

def harvest(path):
    """One pass over a transcript. Returns meta dict, or None if outside window/empty."""
    meta_ok = False
    start_dt = end_dt = None
    cwd = None
    user_n = asst_n = interrupts = in_tok = out_tok = errors = 0
    tools = collections.Counter(); langs = collections.Counter(); errcats = collections.Counter()
    files_mod = set(); tid2name = {}
    first_prompt = None; interactive = False; first_user_seen = False
    hours = []; user_ts = []
    commits = pushes = 0
    uses_task = uses_mcp = uses_ws = uses_wf = False
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            try: d = json.loads(line)
            except Exception: continue
            ts = d.get("timestamp")
            dt = parse_ts(ts) if isinstance(ts, str) else None
            if dt:
                if start_dt is None:
                    start_dt = dt
                    day = ts[:10]
                    if not (START <= day <= END): return None  # outside window: stop reading
                end_dt = dt
            if cwd is None and d.get("cwd"): cwd = d["cwd"]
            typ = d.get("type")
            if typ == "user":
                msg = d.get("message") or {}
                content = msg.get("content")
                txt = text_of(content)
                if not first_user_seen:
                    first_user_seen = True
                    interactive = bool(txt) and not d.get("isSidechain")
                if txt:
                    user_n += 1
                    if first_prompt is None:
                        first_prompt = txt[:197] + "…" if len(txt) > 200 else txt
                    if "[Request interrupted" in txt: interrupts += 1
                    if dt:
                        user_ts.append(ts)
                        hours.append(dt.astimezone().hour)
                if isinstance(content, list):
                    for b in content:
                        if isinstance(b, dict) and b.get("type") == "tool_result" and b.get("is_error"):
                            errors += 1
                            name = tid2name.get(b.get("tool_use_id"), "")
                            rt = b.get("content")
                            if isinstance(rt, list):
                                rt = " ".join(x.get("text", "") for x in rt if isinstance(x, dict))
                            errcats[err_category(name, rt if isinstance(rt, str) else "")] += 1
            elif typ == "assistant":
                asst_n += 1
                msg = d.get("message") or {}
                u = msg.get("usage") or {}
                in_tok += u.get("input_tokens", 0) or 0
                out_tok += u.get("output_tokens", 0) or 0
                for b in msg.get("content") or []:
                    if not (isinstance(b, dict) and b.get("type") == "tool_use"): continue
                    name = b.get("name", "?")
                    tools[name] += 1
                    if b.get("id"): tid2name[b["id"]] = name
                    if name in ("Task", "Agent"): uses_task = True
                    if name.startswith("mcp__"): uses_mcp = True
                    if name == "WebSearch": uses_ws = True
                    if name == "WebFetch": uses_wf = True
                    inp = b.get("input") or {}
                    fp = inp.get("file_path")
                    if isinstance(fp, str) and fp:
                        lang = EXT_LANG.get(os.path.splitext(fp)[1].lower())
                        if lang: langs[lang] += 1
                        if name in ("Edit", "Write", "MultiEdit"): files_mod.add(fp)
                    if name == "Bash":
                        cmd = inp.get("command") or ""
                        if re.search(r"\bgit\b[^\n|;&]*\bcommit\b", cmd): commits += 1
                        if re.search(r"\bgit\b[^\n|;&]*\bpush\b", cmd): pushes += 1
            meta_ok = True
    if not meta_ok or start_dt is None: return None
    dur = round((end_dt - start_dt).total_seconds() / 60, 1) if end_dt else 0
    sid = os.path.splitext(os.path.basename(path))[0]
    return {
        "session_id": sid,
        "project_path": cwd or "",
        "start_time": start_dt.strftime("%Y-%m-%dT%H:%M:%S.") + "%03dZ" % (start_dt.microsecond // 1000),
        "duration_minutes": dur,
        "user_message_count": user_n,
        "assistant_message_count": asst_n,
        "tool_counts": dict(tools),
        "languages": dict(langs),
        "git_commits": commits,
        "git_pushes": pushes,
        "input_tokens": in_tok,
        "output_tokens": out_tok,
        "first_prompt": first_prompt,
        "user_interruptions": interrupts,
        "tool_errors": errors,
        "tool_error_categories": dict(errcats),
        "uses_task_agent": uses_task,
        "uses_mcp": uses_mcp,
        "uses_web_search": uses_ws,
        "uses_web_fetch": uses_wf,
        "files_modified": len(files_mod),
        "message_hours": sorted(set(hours)),
        "user_message_timestamps": user_ts,
        "transcript_mtime": int(os.path.getmtime(path) * 1000),
        "source": "local-harvest",
        "interactive": interactive,
    }

def main():
    os.makedirs(OUT, exist_ok=True)
    files = glob.glob(os.path.join(PROJ, "*", "*.jsonl"))
    best = {}  # sid -> (size, meta); duplicate sids across project dirs: keep largest transcript
    scanned = skipped = 0
    for f in files:
        scanned += 1
        try: m = harvest(f)
        except OSError: m = None
        if m is None:
            skipped += 1; continue
        size = os.path.getsize(f)
        if m["session_id"] not in best or size > best[m["session_id"]][0]:
            best[m["session_id"]] = (size, m)
    inter = 0
    for sid, (_, m) in sorted(best.items()):
        with open(os.path.join(OUT, sid + ".json"), "w") as fh:
            json.dump(m, fh, indent=2)
        if m["interactive"]: inter += 1
    days = sorted(m["start_time"][:10] for _, m in best.values())
    print("harvested %d sessions (%d interactive) from %d transcripts (%d outside %s..%s window)" % (
        len(best), inter, scanned, skipped, START, END))
    if days: print("span: %s .. %s -> %s" % (days[0], days[-1], OUT))

if __name__ == "__main__":
    main()
