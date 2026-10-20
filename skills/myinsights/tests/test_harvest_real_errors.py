"""Tool reliability must score on REAL failures. A 14-day sample (6 Oct 2026) found
about 1 in 5 errors was real: the rest were my own hooks blocking on purpose,
permission prompts, rejections, cancelled siblings and silent exit-1 no-matches.
The harvester keeps the raw count and adds tool_errors_real."""
import importlib.util, json, os, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SKILL = os.path.dirname(HERE)
sys.path.insert(0, SKILL)
spec = importlib.util.spec_from_file_location("harvest_local", os.path.join(SKILL, "harvest_local.py"))
hl = importlib.util.module_from_spec(spec); spec.loader.exec_module(hl)
from scorecard import compute_scores  # noqa: E402

NOISE = [
    "PreToolUse:Bash hook error: [~/.claude/hooks/firewall.sh]: BLOCKED: 'x'",
    "PreToolUse:Bash hook error: [~/.claude/hooks/run-referee-guard.sh]: [run-referee] pause",
    "This Bash command contains multiple operations. The following part requires approval: ls",
    "This command requires approval",
    "The user doesn't want to proceed with this tool use.",
    "Cancelled: parallel tool call Bash errored",
    "<tool_use_error>Sibling tool call errored</tool_use_error>",
    "Exit code 1",
    "Exit code 1\nShell cwd was reset to /home/x",
]
REAL = [
    "Exit code 1\nTraceback (most recent call last):",
    "Exit code 2\nFAIL tests/test_x.py::test_y",
    "Exit code 1\n(eval):1: no matches found: --include=*.cs",
    "File does not exist.",
    "<tool_use_error>String to replace not found in file.</tool_use_error>",
    "Exit code 137",
    "Exit code 124",
    "Exit code 1\ncurl: (22) The requested URL returned error: 403, request was rejected by WAF",
    "Exit code 1\nX Pull request #12 is not mergeable: the base branch policy requires approval",
]


def test_noise_is_not_real():
    for t in NOISE:
        assert hl.is_real_error(t) is False, t


def test_real_is_real():
    for t in REAL:
        assert hl.is_real_error(t) is True, t


def _transcript(texts):
    recs = [{"type": "user", "timestamp": "2026-09-01T10:00:00.000Z", "cwd": "/home/x/Repos/p",
             "entrypoint": "cli", "message": {"content": "go"}}]
    for i, t in enumerate(texts):
        recs.append({"type": "assistant", "timestamp": "2026-09-01T10:01:00.000Z", "entrypoint": "cli",
                     "message": {"content": [{"type": "tool_use", "id": "t%d" % i, "name": "Bash", "input": {}}]}})
        recs.append({"type": "user", "timestamp": "2026-09-01T10:02:00.000Z", "entrypoint": "cli",
                     "message": {"content": [{"type": "tool_result", "tool_use_id": "t%d" % i,
                                              "is_error": True, "content": t}]}})
    f = tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False)
    f.write("\n".join(json.dumps(r) for r in recs)); f.close()
    return f.name


def test_harvest_counts_both():
    hl.START, hl.END = "2026-01-01", "2026-12-31"
    m = hl.harvest(_transcript(NOISE + REAL))
    assert m["tool_errors"] == len(NOISE) + len(REAL)
    assert m["tool_errors_real"] == len(REAL)


def test_scorecard_uses_real_errors_when_present():
    q = json.load(open(os.path.join(HERE, "fixtures", "quant_fixture.json")))
    calls = sum(v for _, v in q["top_tools"])
    q["tool_errors"] = calls // 2
    q["tool_errors_real"] = 0
    F, _ = compute_scores(q)
    tr = [f for f in F if f["name"] == "Tool reliability"][0]
    assert abs(tr["score"] - 100.0) < 1e-9
    assert "real" in tr["ev"]


def test_scorecard_falls_back_to_raw_without_field():
    q = json.load(open(os.path.join(HERE, "fixtures", "quant_fixture.json")))
    q.pop("tool_errors_real", None)
    calls = sum(v for _, v in q["top_tools"])
    F, _ = compute_scores(q)
    tr = [f for f in F if f["name"] == "Tool reliability"][0]
    assert abs(tr["score"] - 100 * (1 - q["tool_errors"] / calls)) < 1e-9


if __name__ == "__main__":
    mod = sys.modules[__name__]; failed = 0
    for name in [n for n in dir(mod) if n.startswith("test_")]:
        try: getattr(mod, name)(); print("PASS", name)
        except Exception as exc: failed += 1; print("FAIL", name, repr(exc))
    raise SystemExit(1 if failed else 0)
