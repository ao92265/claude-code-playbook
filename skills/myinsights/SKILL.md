---
name: myinsights
description: >-
  Generate a MERGED, all-logins Claude Code insights report — the /insights equivalent that covers your
  ENTIRE local session corpus (every account you've logged in as on this machine), not the built-in's
  small sample. Quantitative rollups from all session-meta + a qualitative narrative synthesized from
  the local facets, rendered as a self-contained HTML report. Use when the user says "myinsights",
  "insights across both accounts", "full insights", "all my sessions", "merged insights", "usage report
  for everything", or invokes /myinsights. Do NOT use for the built-in per-account /insights (that's a
  native command) or for account/config status (that's /account-status).
---

# myinsights

The built-in `/insights` samples a subset of sessions and reflects the currently-logged-in view. This produces a report over the **whole local corpus, merged across every login**, because `/login` overwrites only identity (keychain token + `~/.claude.json`), never `~/.claude/projects/**` or `~/.claude/usage-data/**` — all logins' sessions already coexist locally.

**Honesty guardrails (must survive into the report):**
- Sessions on disk carry **no account tag** → the report is *merged*, it cannot split work vs personal. State this.
- Quantitative stats cover **all** session-meta; the qualitative narrative is grounded in the available **facets** (a subset). Don't imply the narrative saw every session.

## Steps

1. **Extract substrate** (deterministic, read-only) into a scratch dir:
   ```bash
   OUT=/tmp/myinsights && python3 "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/skills/myinsights/gather_all.py" "$OUT"
   ```
   Writes `$OUT/quant.json` (rollups: sessions, tokens, commits/pushes, durations, top tools, languages, error categories, by-hour, project areas) and `$OUT/facets_compact.json` (trimmed qualitative facets). Honours `CLAUDE_CONFIG_DIR`.

2. **Synthesize the narrative** — read `$OUT/facets_compact.json` + `$OUT/quant.json` and produce a JSON object at **full /insights depth** (a deep Opus agent, effort high). Ground every claim in the data; cite counts; full-corpus claims use n=sessions framing, sampled claims use n=facets; say "insufficient data" rather than invent. Save to `$OUT/narrative.json`. Exact schema (the renderer degrades gracefully if a block is missing, but aim for all of it):
   ```
   headline: str
   project_areas: [{name, session_count:int, description}]            # 5-6
   interaction_style: {narrative, key_pattern}
   what_works: {intro, impressive_workflows:[{title, description}]}    # 3
   friction: {intro, categories:[{category, description, examples:[]}]} # 3, examples paraphrased from facets
   suggestions: {
     claude_md_additions:[{addition, why, prompt_scaffold}],           # 5  (prompt_scaffold = short "Add under a ## X section" hint)
     features_to_try:[{feature, one_liner, why_for_you, example_code}], # 3
     usage_patterns:[{title, suggestion, detail, copyable_prompt}]     # 3  (detail = 2-3 sentence grounded paragraph)
   }
   on_the_horizon: {intro, opportunities:[{title, whats_possible, how_to_try, copyable_prompt}]}  # 3
   fun_ending: {headline, detail}
   at_a_glance: {whats_working, whats_hindering, quick_wins, ambitious_workflows}
   ```

3. **Render**:
   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/skills/myinsights/render_myinsights.py" "$OUT/quant.json" "$OUT/narrative.json" "$(date '+%Y-%m-%d %H:%M')" "$OUT/report.html"
   ```
   Then call the `Artifact` tool on `$OUT/report.html`. Favicon `📊`, title "myinsights — all logins merged".
   The renderer also computes a **deterministic ranked Scorecard** (9 factors scored 0–100 by disclosed formulas over `quant.json` + facet outcomes, graded A+→D, weighted into a composite) and styles the report on the Linear design system — both are automatic, no narrative input needed.

## Rules
- **Read-only.** Never write into `~/.claude/usage-data` or `projects`. No secrets emitted.
- **Self-contained HTML** — inline CSS + SVG only (Artifact CSP blocks CDNs/fonts/remote images). Charts are hand-rolled SVG/CSS bars; body-only (no `<html>/<head>/<body>`).
- **Numbers are honest** — the renderer reflects `quant.json` exactly. If a field is missing it shows "no data".
- The narrative JSON schema is fixed (step 2 keys); the renderer degrades gracefully if any array is empty ("narrative pending").
