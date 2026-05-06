#!/bin/bash
# PreToolUse hook: warn (don't block) when Claude edits source code without an
# active plan/spec on disk. Encourages "spec first, then code" without
# blocking quick fixes.
#
# Looks for any of, recursively:
#   - tasks/*.md, plans/*.md, .omc/plans/**/*.md (modified in last N days)
#   - any *.spec.md (modified in last N days)
#   - PLAN.md or SPEC.md at repo root
#
# Window defaults to 14 days. Override with PLAN_GATE_WINDOW_DAYS=N.
# Disable with PLAN_GATE_DISABLED=1.
#
# Exit codes:
#   0  plan present OR irrelevant file
#   1  warn (no recent plan)

set -euo pipefail

if [[ "${PLAN_GATE_DISABLED:-0}" == "1" ]]; then exit 0; fi
if ! command -v jq >/dev/null 2>&1; then exit 0; fi

payload="$(cat)"
file="$(jq -r '.tool_input.file_path // empty' <<<"$payload")"
[[ -z "$file" ]] && exit 0

case "$file" in
  *.md|*.mdx|*.json|*.yml|*.yaml|*.toml|*.lock) exit 0 ;;
  */node_modules/*|*/.git/*|*/dist/*|*/build/*) exit 0 ;;
esac
case "$file" in
  *.ts|*.tsx|*.js|*.jsx|*.py|*.go|*.rs|*.java|*.kt|*.cs|*.rb|*.php|*.swift) ;;
  *) exit 0 ;;
esac

repo="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
window="${PLAN_GATE_WINDOW_DAYS:-14}"

# Fast check: any markdown plan/spec touched in the last N days?
found="$(find "$repo" \
  \( -path '*/node_modules' -o -path '*/.git' -o -path '*/dist' -o -path '*/build' \) -prune -o \
  -type f \( \
       -name '*.spec.md' \
    -o -path '*/tasks/*.md' \
    -o -path '*/plans/*.md' \
    -o -path '*/.omc/plans/*.md' \
    -o -name 'PLAN.md' \
    -o -name 'SPEC.md' \
  \) -mtime -"$window" -print -quit 2>/dev/null || true)"

[[ -n "$found" ]] && exit 0

echo "Plan gate: no plan/spec found (looked for tasks/, plans/, .omc/plans/, *.spec.md, PLAN.md, SPEC.md modified within ${window}d)." >&2
echo "  Consider writing a brief plan first (see /writing-plans skill or BMAD/RPI)." >&2
echo "  Bypass: export PLAN_GATE_DISABLED=1." >&2
exit 1
