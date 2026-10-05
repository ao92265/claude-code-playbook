#!/usr/bin/env python3
"""Collect the countable facts for a Innovation Team executive summary from a git repo.

Every figure comes back with the command or rule that produced it, so the
summary's "every number is traceable" rule can be met by quoting the source.
Counts that rest on a file-name or keyword heuristic say so in their source.

Usage:
  python3 repo_metrics.py /path/to/repo            # JSON to stdout
  python3 repo_metrics.py /path/to/repo --markdown # Part 2 table + doc inventory
  python3 repo_metrics.py /path/to/repo --no-github  # skip gh calls (offline)
"""
import argparse
import datetime as dt
import json
import os
import re
import subprocess
import sys

SKIP_DIRS = {
    "node_modules", "dist", "build", "out", "bin", "obj", ".git", ".angular",
    ".next", ".nuxt", "coverage", "vendor", "venv", ".venv", "__pycache__",
    "target", ".omc", ".codegraph",
}
SKIP_PREFIX_PATHS = ("wwwroot/lib/",)  # vendored client libraries in ASP.NET projects
SKIP_SUFFIXES = (
    ".min.js", ".min.css", ".map", ".lock", "package-lock.json", ".Designer.cs",
    ".designer.cs", ".g.cs", "ModelSnapshot.cs", ".snap",
)
LANG = {
    ".cs": "C#", ".vb": "VB.NET", ".ts": "TypeScript", ".tsx": "TypeScript",
    ".js": "JavaScript", ".jsx": "JavaScript", ".mjs": "JavaScript",
    ".py": "Python", ".java": "Java", ".kt": "Kotlin", ".go": "Go",
    ".rb": "Ruby", ".php": "PHP", ".rs": "Rust", ".swift": "Swift",
    ".sql": "SQL", ".html": "HTML", ".scss": "SCSS", ".css": "CSS",
    ".vue": "Vue", ".svelte": "Svelte", ".razor": "Razor", ".cshtml": "Razor",
}
FRONTEND_LANGS = {"TypeScript", "JavaScript", "HTML", "SCSS", "CSS", "Vue", "Svelte"}
DOC_EXT = (".md", ".mdx", ".rst", ".adoc")

# Single-line test-case markers per language (flat patterns, one per line).
TEST_MARKERS = [
    ("C#", re.compile(r"^\s*\[(Fact|Theory|Test|TestMethod|TestCase)\b")),
    ("TS/JS", re.compile(r"^\s*(it|test)(\.each\([^)]*\))?\s*\(\s*['\"`]")),
    ("Python", re.compile(r"^\s*(async\s+)?def\s+test_")),
    ("Java/Kotlin", re.compile(r"^\s*@Test\b")),
    ("Go", re.compile(r"^func\s+Test\w+\(")),
]
ENDPOINT_MARKERS = [
    re.compile(r"\.Map(Get|Post|Put|Delete|Patch)\s*\("),         # .NET minimal API
    re.compile(r"\[Http(Get|Post|Put|Delete|Patch)\b"),            # ASP.NET controllers
    re.compile(r"\b(router|app)\.(get|post|put|delete|patch)\s*\(\s*['\"`]"),  # Express
    re.compile(r"@(app|router)\.(get|post|put|delete|patch)\s*\("),  # FastAPI
    re.compile(r"@\w+\.route\s*\("),                               # Flask
    re.compile(r"@(Get|Post|Put|Delete|Patch)Mapping\b"),          # Spring
    re.compile(r"^\s*@(Get|Post|Put|Delete|Patch|All)\s*\("),        # NestJS controllers
]
AI_DEPS = ("anthropic", "openai", "azure.ai", "azure-ai", "langchain", "litellm",
           "semantic-kernel", "semantickernel", "google-genai", "@google/generative-ai",
           "bedrock", "ollama", "mistral", "cohere")
BOT_HINTS = ("[bot]", "-bot", "copilot", "codex", "claude", "dependabot", "github-actions")


def run(cmd, cwd, timeout=120):
    try:
        p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True,
                           timeout=timeout, stdin=subprocess.DEVNULL)
        return p.returncode, p.stdout, p.stderr
    except (OSError, subprocess.TimeoutExpired) as e:
        return 1, "", str(e)


def m(value, source):
    return {"value": value, "source": source}


def tracked_files(repo):
    rc, out, _ = run(["git", "ls-files", "-z"], repo)
    files = [f for f in out.split("\0") if f]
    nuget_restore = any(f.endswith("packages.config") for f in files)
    keep = []
    for f in files:
        if nuget_restore and f.split("/")[0] == "packages":
            continue
        parts = f.split("/")
        if any(p in SKIP_DIRS for p in parts[:-1]) or f.endswith(SKIP_SUFFIXES) \
                or any(x in f.lower() for x in SKIP_PREFIX_PATHS):
            continue
        keep.append(f)
    return keep


def is_test_path(f):
    low = f.lower()
    name = os.path.basename(low)
    return (
        any(seg in ("test", "tests", "__tests__", "spec", "specs", "e2e", "playwright")
            or seg.endswith(".tests") or seg.endswith(".test") or seg.endswith("tests")
            for seg in low.split("/")[:-1])
        or ".spec." in name or ".test." in name or name.startswith("test_")
        or name.endswith("tests.cs") or name.endswith("test.cs") or name.endswith("_test.go")
    )


BACKEND_DIRS = {"backend", "server", "api", "functions", "lambda", "services", "worker", "workers"}
FRONTEND_DIRS = {"frontend", "client", "web", "ui", "webapp", "spa"}
NODE_BACKEND_DEPS = ("@nestjs/core", "express", "fastify", "koa", "@hapi/hapi", "hono",
                     "@azure/functions", "aws-lambda")
_PKG_CACHE = {}


def node_backend_package(repo, f, tracked):
    """True if the nearest tracked package.json above f declares a server framework."""
    d = os.path.dirname(f)
    while True:
        pj = (d + "/package.json") if d else "package.json"
        if pj in tracked:
            if pj not in _PKG_CACHE:
                try:
                    data = json.load(open(os.path.join(repo, pj)))
                    deps = dict(data.get("dependencies") or {}, **(data.get("devDependencies") or {}))
                    front = any(k in deps for k in ("@angular/core", "react", "vue", "svelte"))
                    _PKG_CACHE[pj] = any(k in deps for k in NODE_BACKEND_DEPS) and not front
                except (OSError, ValueError):
                    _PKG_CACHE[pj] = False
            return _PKG_CACHE[pj]
        if not d:
            return False
        d = os.path.dirname(d)


def side(repo, f, lang, tracked):
    """frontend or backend. Path names first, then the nearest package.json for TS/JS."""
    if lang not in FRONTEND_LANGS:
        return "backend"
    if lang in ("HTML", "SCSS", "CSS", "Vue", "Svelte"):
        return "frontend"
    segs = set(f.lower().split("/")[:-1])
    if segs & FRONTEND_DIRS:
        return "frontend"
    if segs & BACKEND_DIRS:
        return "backend"
    return "backend" if node_backend_package(repo, f, tracked) else "frontend"


def test_layer(f, where):
    low = f.lower()
    if "e2e" in low or "playwright" in low or "cypress" in low:
        return "end-to-end"
    if where == "frontend":
        return "frontend"
    return "backend integration" if "integration" in low else "backend unit"


def read_lines(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            return fh.read().splitlines()
    except OSError:
        return []


def git_facts(repo):
    facts = {}
    rc, shallow, _ = run(["git", "rev-parse", "--is-shallow-repository"], repo)
    facts["shallow_clone"] = m(shallow.strip() == "true", "git rev-parse --is-shallow-repository")
    rc, ref, _ = run(["git", "symbolic-ref", "--short", "refs/remotes/origin/HEAD"], repo)
    ref = ref.strip() or "HEAD"
    facts["counted_ref"] = m(ref, "git symbolic-ref refs/remotes/origin/HEAD (falls back to HEAD)")
    rc, n, _ = run(["git", "rev-list", "--count", ref], repo)
    facts["commits"] = m(int(n.strip() or 0), "git rev-list --count " + ref)
    rc, first, _ = run(["git", "log", ref, "--reverse", "--format=%as", "--max-parents=0"], repo)
    rc, last, _ = run(["git", "log", ref, "-1", "--format=%as"], repo)
    rc, days, _ = run(["git", "log", ref, "--format=%as"], repo)
    active = sorted(set(days.split()))
    first = active[0] if active else ""
    last = active[-1] if active else ""
    facts["first_commit"] = m(first, "earliest author date on " + ref)
    facts["last_commit"] = m(last, "latest author date on " + ref)
    facts["active_days"] = m(len(active), "distinct commit dates on " + ref)
    if first and last:
        span = (dt.date.fromisoformat(last) - dt.date.fromisoformat(first)).days + 1
        facts["calendar_days"] = m(span, "last commit date minus first, inclusive")
        if span:
            facts["commits_per_calendar_day"] = m(
                round(facts["commits"]["value"] / span, 1), "commits / calendar_days")
    rc, auth, _ = run(["git", "shortlog", "-sne", ref], repo)
    authors = []
    for line in auth.splitlines():
        line = line.strip()
        if "\t" in line:
            c, who = line.split("\t", 1)
            authors.append({"commits": int(c), "author": who})
    facts["authors"] = m(authors, "git shortlog -sne " + ref)
    return facts


def github_facts(repo):
    rc, url, _ = run(["git", "remote", "get-url", "origin"], repo)
    if "github.com" not in url:
        return {"note": m("origin is not GitHub; PR and issue counts need the host's own tooling "
                          "(Azure DevOps: az repos pr list)", "git remote get-url origin")}
    rc, nwo, _ = run(["gh", "repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"], repo)
    nwo = nwo.strip()

    def search_total(q):
        rc2, o, _ = run(["gh", "api", "-X", "GET", "search/issues", "-f", "q=repo:%s %s" % (nwo, q),
                         "-f", "per_page=1", "-q", ".total_count"], repo)
        return int(o.strip()) if rc2 == 0 and o.strip().isdigit() else None

    rc, out, err = run(["gh", "pr", "list", "--state", "merged", "--limit", "3000",
                        "--json", "number,author,reviews,mergedAt"], repo, timeout=300)
    if rc != 0:
        return {"note": m("gh call failed: " + err.strip()[:200], "gh pr list --state merged")}
    prs = json.loads(out or "[]")
    independent = self_only = bot_only = 0
    for pr in prs:
        pa = ((pr.get("author") or {}).get("login") or "").lower()
        who = {((rv.get("author") or {}).get("login") or "").lower() for rv in pr.get("reviews") or []}
        who.discard("")
        humans = {w for w in who if not any(b in w for b in BOT_HINTS)}
        if humans - {pa}:
            independent += 1
        elif pa in humans:
            self_only += 1
        elif who:
            bot_only += 1
    n = len(prs)
    total_merged = search_total("is:pr is:merged") if nwo else None
    sample_note = "" if not total_merged or total_merged <= n else (
        ". Review breakdown covers the most recent %d of %d merged PRs" % (n, total_merged))
    pct = lambda k: round(100.0 * k / n, 1) if n else 0
    facts = {
        "merged_prs": m(total_merged or n, "GitHub search API total for is:pr is:merged"
                        if total_merged else "gh pr list --state merged"),
        "independent_human_review": m(
            {"prs": independent, "pct": pct(independent)},
            "merged PRs reviewed by a non-bot account OTHER than the author. This is the number "
            "to call human review" + sample_note),
        "self_account_review_only": m(
            {"prs": self_only, "pct": pct(self_only)},
            "merged PRs whose only human-account review came from the author's own account "
            "(often an agent session posting as the author). Not independent review"),
        "bot_review_only": m({"prs": bot_only, "pct": pct(bot_only)},
                             "merged PRs reviewed only by bot accounts"),
        "no_review_recorded": m({"prs": n - independent - self_only - bot_only,
                                 "pct": pct(n - independent - self_only - bot_only)},
                                "merged PRs with no GitHub review object. Reviews held in other "
                                "tools (pairing, Teams) are not seen"),
    }
    issues = search_total("is:issue") if nwo else None
    if issues is not None:
        facts["issues"] = m(issues, "GitHub search API total for is:issue")
    return facts


def code_facts(repo, files):
    tracked = set(files)
    loc_side = {"backend": 0, "frontend": 0}
    loc = {}
    prod_files = {}
    test_cases = {}
    test_files = {}
    endpoints = 0
    components = 0
    pages = set()
    migrations = set()
    ci = []
    stack = {}
    ai_hits = set()
    docs = []
    agent_ctx = []

    for f in files:
        path = os.path.join(repo, f)
        low = f.lower()
        base = os.path.basename(low)
        ext = os.path.splitext(low)[1]
        segs = low.split("/")

        if low.startswith(".github/workflows/") or base in (
                "azure-pipelines.yml", ".gitlab-ci.yml", "jenkinsfile", "bitbucket-pipelines.yml"):
            ci.append(f)
        if ext in DOC_EXT:
            if segs[0] in (".claude", ".cursor", ".github", ".omc") or base in (
                    "claude.md", "agents.md", "gemini.md", ".cursorrules"):
                agent_ctx.append({"path": f, "lines": len(read_lines(path))})
            else:
                docs.append({"path": f, "lines": len(read_lines(path))})
            continue

        # migrations: EF Core, Flyway/Liquibase/plain SQL, Alembic, Prisma, Rails
        if "migrations" in segs or "migration" in segs or "versions" in segs:
            if ext in (".cs", ".sql", ".py", ".rb", ".ts", ".js") and not base.startswith("__init__"):
                migrations.add(f if "prisma" not in low else os.path.dirname(f))

        if base == "package.json" and "node_modules" not in low:
            try:
                pj = json.load(open(path))
                deps = dict(pj.get("dependencies") or {}, **(pj.get("devDependencies") or {}))
                for k in ("@angular/core", "react", "vue", "svelte", "next", "typescript", "vite",
                          "vitest", "jest", "@playwright/test", "cypress", "tailwindcss",
                          "@tanstack/react-query", "i18next", "@ngx-translate/core"):
                    if k in deps:
                        stack[k] = deps[k]
                for k in deps:
                    if any(a in k.lower() for a in AI_DEPS):
                        ai_hits.add(f + ": " + k)
            except (OSError, ValueError):
                pass
        if ext in (".csproj", ".fsproj", ".vbproj"):
            for line in read_lines(path):
                s = line.strip()
                if s.startswith("<TargetFramework"):
                    stack.setdefault("dotnet_target", set()).add(s.split(">")[1].split("<")[0])
                if s.startswith("<PackageReference"):
                    name = s.split('Include="')[1].split('"')[0] if 'Include="' in s else ""
                    ver = s.split('Version="')[1].split('"')[0] if 'Version="' in s else ""
                    if name:
                        stack.setdefault("nuget", {})[name] = ver
                        if any(a in name.lower() for a in AI_DEPS):
                            ai_hits.add(f + ": " + name)
        if (base.startswith("requirements") and base.endswith(".txt")) or base in (
                "setup.py", "setup.cfg", "pyproject.toml", "go.mod", "pom.xml", "build.gradle",
                    "docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml",
                    "dockerfile"):
            stack.setdefault("manifests", []).append(f)
            for line in read_lines(path):
                if any(a in line.lower() for a in AI_DEPS):
                    ai_hits.add(f + ": " + line.strip()[:80])

        lang = LANG.get(ext)
        if not lang:
            continue
        lines = read_lines(path)
        n = sum(1 for l in lines if l.strip())
        where = side(repo, f, lang, tracked)
        if is_test_path(f):
            layer = test_layer(f, where)
            test_files[layer] = test_files.get(layer, 0) + 1
            for label, rx in TEST_MARKERS:
                c = sum(1 for l in lines if rx.match(l))
                if c:
                    test_cases[layer] = test_cases.get(layer, 0) + c
            loc.setdefault("tests", {})
            loc["tests"][lang] = loc["tests"].get(lang, 0) + n
            continue
        loc.setdefault("production", {})
        loc["production"][lang] = loc["production"].get(lang, 0) + n
        prod_files[lang] = prod_files.get(lang, 0) + 1
        loc_side[where] += n
        for l in lines:
            if any(rx.search(l) for rx in ENDPOINT_MARKERS):
                endpoints += 1
            if "@Component(" in l:
                components += 1
        stem = os.path.splitext(base)[0]
        if ext in (".ts", ".tsx", ".jsx", ".vue", ".svelte") and (
                stem.endswith(("-page", ".page", "page.component", "-page.component"))
                or (segs[:-1] and segs[-2] in ("pages", "views", "screens") and ".spec" not in base)
                or (base in ("page.tsx", "page.jsx") and "app" in segs)
                or stem.endswith("page")):
            pages.add(f)

    # React/Vue/Svelte projects: count component files when no Angular decorators exist
    if not components:
        components = sum(1 for f in files if f.lower().endswith((".tsx", ".jsx", ".vue", ".svelte"))
                         and not is_test_path(f))
        comp_src = "component files (.tsx/.jsx/.vue/.svelte, excluding tests)"
    else:
        comp_src = "count of @Component( decorators"

    if "dotnet_target" in stack:
        stack["dotnet_target"] = sorted(stack["dotnet_target"])
    prod = loc.get("production", {})
    facts = {
        "loc_production_total": m(sum(prod.values()),
                                  "non-blank lines in tracked source, excluding tests, generated, "
                                  "vendored and lock files"),
        "loc_production_by_language": m(dict(sorted(prod.items(), key=lambda kv: -kv[1])), "same rule, per extension"),
        "production_files_by_language": m(prod_files, "tracked source files per extension, excluding tests"),
        "loc_backend": m(loc_side["backend"],
                         "production lines in server languages, plus TS/JS under backend/server/api "
                         "dirs or in a package whose package.json declares a server framework"),
        "loc_frontend": m(loc_side["frontend"],
                          "production lines in HTML/CSS/Vue/Svelte and the remaining TS/JS"),
        "loc_tests": m(loc.get("tests", {}), "non-blank lines in test paths, per language"),
        "test_cases_by_layer": m(test_cases, "heuristic: [Fact]/[Theory]/[Test], it(/test(, def test_, @Test, func Test"),
        "test_files_by_layer": m(test_files, "heuristic: test path and file-name conventions"),
        "migrations": m(len(migrations), "heuristic: source files under migrations/ or versions/ dirs, "
                                         "excluding EF Designer and snapshot files"),
        "endpoints": m(endpoints, "heuristic: MapGet, [HttpGet], router.get, @app.get, @app.route, @GetMapping, NestJS @Get( lines"),
        "frontend_components": m(components, comp_src),
        "frontend_pages": m(len(pages), "heuristic: *-page.ts, *.page.ts, *Page.tsx, files in pages/views/screens, "
                                        "Next.js page.tsx. Check against the router"),
        "ci_files": m(ci, "workflow files found"),
        "stack": m(stack, "package.json, *.csproj and manifest files"),
        "runtime_ai_dependencies": m(sorted(ai_hits), "dependency names matching known model SDKs. "
                                                      "Empty usually means AI was build-time only"),
    }
    docs.sort(key=lambda d: -d["lines"])
    facts["documentation_lines"] = m(sum(d["lines"] for d in docs), "lines in tracked .md/.mdx/.rst/.adoc")
    facts["documentation_files"] = m(len(docs), "tracked .md/.mdx/.rst/.adoc files")
    facts["documentation_top20"] = m(docs[:20], "largest docs by line count")
    facts["agent_context_files"] = m(sorted(agent_ctx, key=lambda d: -d["lines"]),
                                     "CLAUDE.md, AGENTS.md, .claude/, .github/ and similar agent "
                                     "context, kept out of the documentation count")
    return facts


def markdown(r):
    v = lambda k: r[k]["value"] if k in r and isinstance(r[k], dict) else "n/a"
    lines = []
    lines.append("Figures captured from the repository on %s (ref %s)." % (r["captured"], v("counted_ref")))
    if v("shallow_clone") is True:
        lines.append("WARNING: shallow clone. Commit counts and dates are wrong. Run "
                     "`git fetch --unshallow` and re-run.")
    lines.append("")
    lines.append("| Metric | Value | Source |")
    lines.append("|---|---|---|")
    rows = [
        ("Total lines of production code", "loc_production_total"),
        ("Backend lines", "loc_backend"), ("Frontend lines", "loc_frontend"),
        ("Total commits", "commits"), ("First commit", "first_commit"),
        ("Commits per calendar day", "commits_per_calendar_day"),
        ("Merged pull requests", "merged_prs"),
        ("Independent human review", "independent_human_review"),
        ("Self-account review only", "self_account_review_only"),
        ("Bot review only", "bot_review_only"), ("No review recorded", "no_review_recorded"),
        ("Issues tracked", "issues"), ("Database migrations", "migrations"),
        ("API endpoints", "endpoints"), ("Frontend components", "frontend_components"),
        ("Frontend pages", "frontend_pages"), ("Test cases by layer", "test_cases_by_layer"),
        ("Documentation lines", "documentation_lines"),
    ]
    for label, key in rows:
        if key in r:
            lines.append("| %s | %s | %s |" % (label, json.dumps(r[key]["value"]) if isinstance(r[key]["value"], dict) else r[key]["value"], r[key]["source"]))
    lines.append("")
    lines.append("| Document | Lines |")
    lines.append("|---|---|")
    for d in v("documentation_top20") or []:
        lines.append("| %s | %d |" % (d["path"], d["lines"]))
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("repo")
    ap.add_argument("--markdown", action="store_true")
    ap.add_argument("--no-github", action="store_true")
    ap.add_argument("--out", help="write metrics.json and metrics.md into this folder in one run")
    a = ap.parse_args()
    repo = os.path.abspath(os.path.expanduser(a.repo))
    rc, _, _ = run(["git", "rev-parse", "--git-dir"], repo)
    if rc != 0:
        sys.exit("not a git repository: " + repo)
    r = {"repo": repo, "captured": dt.date.today().isoformat()}
    r.update(git_facts(repo))
    if not a.no_github:
        r.update(github_facts(repo))
    r.update(code_facts(repo, tracked_files(repo)))
    if r["shallow_clone"]["value"]:
        print("WARNING: shallow clone, git counts are incomplete. git fetch --unshallow first.",
              file=sys.stderr)
    if a.out:
        os.makedirs(a.out, exist_ok=True)
        with open(os.path.join(a.out, "metrics.json"), "w") as fh:
            json.dump(r, fh, indent=2, default=list)
        with open(os.path.join(a.out, "metrics.md"), "w") as fh:
            fh.write(markdown(r) + "\n")
        print("wrote metrics.json and metrics.md to " + a.out)
        return
    print(markdown(r) if a.markdown else json.dumps(r, indent=2, default=list))


if __name__ == "__main__":
    main()
