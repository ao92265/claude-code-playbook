# /myinsights — Local, Full-Corpus, Merged-Identity Claude Code Insights Report

## Problem
The built-in Claude Code /insights command sampled only 93 of 1340 sessions (~7%) and reports per-account, so it undercounts one person's real usage and cannot see across their two logins (personal + work, same individual). Because /login only swaps the keychain token and the oauthAccount in ~/.claude.json — it never rewrites session history — all sessions from both logins already coexist under ~/.claude with NO account tag on disk. The user wants a local, read-only, self-contained report that (a) covers far more of the corpus than the built-in tool, (b) merges both logins into one honest picture (segmentation is impossible, not merely unperformed), and (c) does not repeat the built-in tool's core failure of dressing a tiny non-representative sample as full-corpus truth.

## Goal
Ship /myinsights as a packaged Claude Code skill that renders a single self-contained HTML report from two already-materialized snapshots (quant.json for full-corpus quantitative rollups over 600 session-meta records; facets_compact.json for a 107-session qualitative sample). The report presents merged, honest, tiered-coverage insights — leading with the 93-vs-600 coverage win and an explicit statement that data is merged/not-account-segmented because sessions carry no identity tag — using inline hand-rolled SVG charts, no CDN, no re-LLM pass, and a visible freshness/as-of banner.

## Non-goals
- Per-account or personal-vs-work segmentation of any kind — no time-of-day or project-area proxy splits (data has no account tag; user explicitly wants merged).
- Re-running any LLM summarization pass over the ~4011 sessions lacking facets — the 107 facets are used verbatim as illustrative color only, never re-generated.
- Re-parsing raw .jsonl transcripts at report time — the report Reads only quant.json + facets_compact.json (plus a lightweight session-meta count/mtime scan for the freshness banner).
- Extrapolating qualitative-sample percentages (n=107) to the full corpus, or blending a sampled percentage into a full-corpus chart.
- Per-tool-per-project error cross-tabs or per-tool cost attribution (error taxonomy is 57% 'Other'; tools don't map 1:1 to token spend).
- Any write to ~/.claude — the report is strictly read-only.
- Precise dollar billing — cost is an explicitly-caveated estimate only, since model tier is not logged per session.

## Data sources
- quant.json (3.6K) — full-corpus deterministic rollups over 600 session-meta records. Confirmed fields: sessions=600, input_tokens=15049511, output_tokens=37492178, commits=356, pushes=178, user_msgs=1800, asst_msgs=32132, total_minutes=73309, tool_errors=474, task_agent_sessions=40, mcp_sessions=35, websearch_sessions=7, total_hours=1222, median_session_min=3, median_output_tokens=4855, active_days=14, lines_added=57402, lines_removed=4807, top_tools (12), top_languages (9), error_categories (7), by_hour (24), top_project_areas (15), busiest_days (10), facet_count=107.
- facets_compact.json (63.3K) — list of 107 qualitative facet objects. Confirmed per-item keys: goal, outcome, primary_success, frictions, goal_categories, summary. Confirmed outcome distribution: mostly_achieved 40, fully_achieved 39, unclear_from_transcript 12, partially_achieved 12, not_achieved 4. Frictions: buggy_code 41, wrong_approach 35, misunderstood_request 9, user_rejected_action 6, missing_context 1. Goal categories (raw, needs collapsing): feature_implementation 15, warmup_minimal 14, documentation 14, debugging 13, bug_fixing 11, code_review 8, environment_setup 5, git_operations 4, refactoring 3, code_review_audit 3, testing_qa 3, data_analysis 3.
- ~/.claude/projects/**/*.jsonl and session-meta files — scanned ONLY for a count + newest-mtime freshness banner (as-of stamp), never parsed for content at report time.
- Both files live at $TMPDIR/claude/c77baae8-c980-4a59-86e6-c7dce8f13213/scratchpad/ during this build; the packaged skill will read from a stable configured path.

## Metrics
- Coverage: report processes 600/600 available session-meta records (vs built-in 93/1340) — the headline credibility number, shown with all three denominators (4118 raw files / 600 metered / 107 narrated).
- Honesty: every qualitative (facet-derived) figure carries a visible inline '(n=107, sampled)' badge; every quant figure carries a 'full corpus n=600' badge; no chart mixes the two denominators.
- Self-containment: rendered HTML passes Artifact CSP — zero external requests (no CDN, no external fonts/images); all charts are inline SVG.
- Read-only: a run performs zero writes under ~/.claude (verifiable by mtime diff of ~/.claude before/after).
- Freshness: report header stamps quant.json + facets_compact.json mtimes and a live ~/.claude session-meta count so stale snapshots are visible, not silent.
- Cost: on-demand render completes with no LLM summarization invocation (pure Read + local render).

## Report sections
### 0. Coverage & Credibility Banner (top)
Lead line: '600 sessions analyzed vs the built-in /insights' 93 — merged across both your logins.' State the three tiers with denominators: 4118 raw session files -> 600 with usable session-meta (quant layer, exhaustive) -> 107 with qualitative facets (18% sample). One sentence: 'Merged usage across both logins, not split by account — Claude Code does not tag session history by identity, and both logins are the same person, so merging is the correct and honest representation (no per-account breakdown is possible, not just unperformed).' As-of freshness stamp: quant.json/facets_compact.json mtimes + live session-meta count.
### 1. At-a-Glance
Lead with robust stats, NOT misleading sums: active_days (14), sessions (600), commits (356) / pushes (178), median session length (3 min = mostly quick tasks), median_output_tokens (4855). Footnote total_hours (1222): 'sum of wall-clock across concurrent/overlapping sessions (multiple terminals), NOT elapsed calendar time — do not read as ~87h/day.'
### 2. Where You Worked
Named project-areas bar chart: open-design (50), home~ (48), Repos (35), project-a-act (17), etc. scratch/worktree (384) shown as a SEPARATE caveat bar, explicitly labeled 'ephemeral git worktrees — absorbs ~64% of sessions, not a single project; excluded from the named ranking.'
### 3. What You Used
Inline SVG bars for top_tools (Bash 7482, Read 2278, Edit 1919, Write 496, chrome computer 382...) and top_languages (TypeScript 2019, Markdown 927, JavaScript 654, Python 261...). Delegated work broken out on its own row: task_agent_sessions 40 (do NOT fold subagent tool use into parent tallies), mcp_sessions 35, websearch_sessions 7.
### 4. When You Work
24-cell SVG heatmap strip from by_hour; call out busiest hour and busiest_days (2026-06-26 with 228). Labeled descriptively as a rhythm indicator ('when you work'), explicitly NOT diagnostically ('which login').
### 5. What Works / Friction (SAMPLED n=107)
Two-tier badge mandatory. Outcome distribution with visible denominator: mostly_achieved 40, fully_achieved 39, partially_achieved 12, unclear_from_transcript 12 (shown, not dropped — content lost to API errors), not_achieved 4. Frictions: buggy_code 41, wrong_approach 35, misunderstood_request 9. Goal categories COLLAPSED to a canonical taxonomy before charting (merge code_review + code_review_audit variants; bug_fixing + debugging kept distinct or noted). Phrasing scoped to 'in the 107 sessions with narrative summaries...', never 'X% of all sessions'.
### 6. The Numbers That Sting
Dry-humour honesty panel (full corpus): 37.5M output vs 15.0M input tokens (2.5:1 ratio), 474 tool errors, lines_added 57402 vs lines_removed 4807. Error categories as directional only: 'largest bucket is unclassified — Other 271 of 474 (57%) — so treat the breakdown as directional.' Command Failed 153, File Not Found 19, User Rejected 14.
### 7. Estimated Cost
Estimate from total input/output tokens against published per-model rates, presented as a RANGE with mandatory caveat: 'model tier is not logged per session, so this is a blended-rate estimate, not a bill.'
### 8. Suggestions
2-3 concrete, data-grounded nudges, e.g.: 7482 Bash calls against 474 errors — watch retry loops; 2.5:1 output:input ratio suggests heavy generation, consider tighter prompts / cheaper model tiers per the CLAUDE.md Opus-vs-Sonnet-vs-Haiku economics rule.
### 9. Easter-egg one-liner
A single fun stat styled as a footer (busiest hour, or longest single session), light closing tone.

## Assumptions
- The two logins belong to the same individual, so merging (not segmenting) is correct — stated explicitly per user instruction.
- quant.json and facets_compact.json are already materialized and correct; the render step trusts them as snapshots and does not recompute rollups. The gather script that produced quant.json already exists and is out of scope to rebuild.
- total_hours (1222) over 14 active_days reflects summed concurrent wall-clock across parallel terminals, not elapsed time — reframed accordingly rather than presented as a daily rate.
- scratch/worktree (384) is an ephemeral-worktree labeling artifact, not a real top project.
- The 4118 raw / 600 metered figures are the honest corpus denominators; the ~3518 unmetered files are largely sub-1-turn/aborted/tool-only noise (stated as likely, not certain).
- The 107 facets are a non-random sample (whichever sessions got extracted), so their distributions are anecdotal/illustrative, not representative — never extrapolated.
- Per-session model tier is not recorded, so any cost figure is an estimate.
- Published Claude API per-model token rates are fetched via the claude-api skill at build time rather than hardcoded from memory.

## Risks
- Coverage overclaim: presenting 600/4118 or 107/600 derived stats as full-corpus truth would repeat the exact built-in /insights failure (93/1340) that motivates this build. Mitigation: three explicit denominators + per-chart n badges.
- Silent staleness: a run against a frozen snapshot looks live. Mitigation: header stamps both file mtimes + a live ~/.claude session-meta count; report tells user how to recompute quant.json.
- Sample bias in the 107-facet layer: non-random 18% subset; goal/outcome/friction distributions are anecdotal. Mitigation: 'sampled n=107' badge inline on every facet figure, unclear_from_transcript (12) kept in the denominator.
- scratch/worktree misread as top project. Mitigation: broken out as a caveat bar, excluded from named ranking.
- total_hours misread as ~87h/day. Mitigation: reframed at-a-glance to active_days/median; total_hours footnoted as concurrent-sum.
- Double-counting delegated work: subagent runs may already sit inside parent tool counts. Mitigation: task_agent (40) / mcp (35) / websearch (7) shown as their own 'delegated' row, not folded in.
- Cost estimate read as a bill. Mitigation: range + 'model mix not logged' caveat prominent.
- Error breakdown over-trusted despite 57% 'Other'. Mitigation: labeled directional-only.
- Merged-login framing challenged later if user wants a split. Mitigation: state up front that no data path exists to retrofit the distinction — it's a data limitation, not a design choice.

## Implementation steps
1. 1. GATHER (already done, do not rebuild): the existing script scans ~/.claude session-meta -> quant.json (full-corpus deterministic rollups over 600 records) and the facet extraction produced facets_compact.json (107 qualitative objects). Confirmed present at the scratchpad path. Skill will reference these via a configured, stable input path.
2. 2. FRESHNESS PROBE: at render time, Read quant.json + facets_compact.json and stat their mtimes; do a lightweight glob/count of ~/.claude/projects session-meta files for a live session count. No content parsing, no writes.
3. 3. RENDER SCRIPT (self-contained HTML): a single script (Python or Node, no external deps) that Reads the two JSON files and emits one .html file. Hand-roll inline <svg> for: horizontal bars (top_tools, top_languages, named project areas, collapsed goal_categories), a 24-cell by_hour heatmap strip, and a stacked/segmented bar for the outcome mix. System font stack, inline CSS/JS only, wide tables/charts wrapped in overflow-x:auto. No CDN, no chart lib — matches Artifact CSP.
4. 4. HONESTY GUARDS baked into the template: three-denominator banner (4118/600/107); per-section coverage badge ('full corpus n=600' vs 'sampled n=107'); scratch/worktree caveat bar; total_hours concurrent-sum footnote; delegated-work row; 'Other 57%' error caveat; cost-estimate caveat; merged-not-segmented statement.
5. 5. TAXONOMY COLLAPSE: before charting goal_categories, map near-duplicate labels to a canonical set (e.g. code_review + code_review_audit -> code_review) so one dominant category isn't visually fragmented; keep the mapping in a small dict in the render script.
6. 6. COST: fetch current per-model rates via the claude-api skill; compute a blended-rate range from input_tokens/output_tokens; render as an estimate with the model-tier-not-logged caveat.
7. 7. PUBLISH: pass the rendered HTML file to the Artifact tool (stable favicon, e.g. '📊', stable title '/myinsights') so redeploys hit the same URL; load the artifact-design skill first to calibrate design effort.
8. 8. PACKAGE AS SKILL: author skills/myinsights/SKILL.md (per skill-authoring best practices) with frontmatter name 'myinsights' + trigger description ('/myinsights', 'my insights', 'full insights report'); the skill body = Read the two JSON snapshots -> run freshness probe -> run render script -> publish Artifact. Keep it a pure Read + local render (no LLM pass, no ~/.claude writes) so it is cheap to run on demand.
9. 9. VERIFY: confirm zero writes under ~/.claude (mtime diff), confirm HTML makes no external requests, spot-check that every facet-derived number shows its n badge and no chart blends the two denominators.
