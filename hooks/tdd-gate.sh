#!/bin/bash
# PreToolUse hook: warn (or block, if TDD_GATE_BLOCK=1) when Claude edits a
# production source file that has no matching test file. Pairs with the
# `test-first` skill — soft default is warn-only so it does not get in the
# way during exploratory work.
#
# Skips:
#   - test files themselves (*.test.*, *.spec.*, _test.go, test_*.py)
#   - infra/config (Dockerfile, *.yml, *.json, .github/**, prisma/**)
#   - migrations and generated code
#   - documentation (*.md, *.mdx)
#
# Exit codes:
#   0  has tests OR irrelevant file
#   1  warn (no tests)
#   2  block (only when TDD_GATE_BLOCK=1)
#
# Emergency disable: TDD_GATE_DISABLED=1.

set -euo pipefail

if [[ "${TDD_GATE_DISABLED:-0}" == "1" ]]; then exit 0; fi
if ! command -v jq >/dev/null 2>&1; then exit 0; fi

payload="$(cat)"
file="$(jq -r '.tool_input.file_path // empty' <<<"$payload")"
[[ -z "$file" ]] && exit 0

# Skip non-source files.
case "$file" in
  *.test.*|*.spec.*|*_test.go|*test_*.py|*Test.java|*Tests.cs) exit 0 ;;
  *.md|*.mdx|*.json|*.yml|*.yaml|*.toml|*.lock|Dockerfile*|*.dockerfile) exit 0 ;;
  *.css|*.scss|*.html|*.svg|*.png|*.jpg|*.gif) exit 0 ;;
  */migrations/*|*/generated/*|*/__generated__/*|*/.next/*|*/dist/*|*/build/*) exit 0 ;;
  */node_modules/*|*/vendor/*|*/.git/*) exit 0 ;;
  */prisma/schema.prisma|*/.github/*|*/scripts/*) exit 0 ;;
esac

# Only enforce on recognised source extensions.
case "$file" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs) ;;
  *.py|*.go|*.rs|*.java|*.kt|*.cs|*.rb|*.php|*.swift) ;;
  *) exit 0 ;;
esac

base="$(basename "$file")"
name="${base%.*}"
ext="${base##*.}"
dir="$(dirname "$file")"

# Hunt for a matching test file. Cheap globs only — keep the hook fast.
matches=()
shopt -s nullglob globstar 2>/dev/null || true
case "$ext" in
  ts|tsx|js|jsx|mjs|cjs)
    for cand in \
      "$dir/$name.test.$ext" "$dir/$name.spec.$ext" \
      "$dir/__tests__/$name.test.$ext" "$dir/__tests__/$name.spec.$ext" \
      tests/**/"$name".test.* tests/**/"$name".spec.* \
      test/**/"$name".test.* test/**/"$name".spec.*; do
      [[ -f "$cand" ]] && matches+=("$cand")
    done
    ;;
  py)
    for cand in "$dir/test_$name.py" tests/**/"test_$name.py" tests/**/"${name}_test.py"; do
      [[ -f "$cand" ]] && matches+=("$cand")
    done
    ;;
  go)
    [[ -f "$dir/${name}_test.go" ]] && matches+=("$dir/${name}_test.go")
    ;;
  rs)
    grep -lE '^[[:space:]]*#\[cfg\(test\)\]' "$file" 2>/dev/null && matches+=("$file:inline")
    [[ -f "$dir/../tests/${name}.rs" ]] && matches+=("$dir/../tests/${name}.rs")
    ;;
  java|kt)
    for cand in src/test/**/"${name}Test.$ext" src/test/**/"${name}Tests.$ext"; do
      [[ -f "$cand" ]] && matches+=("$cand")
    done
    ;;
  cs)
    for cand in **/"${name}Tests.cs" **/"${name}.Tests.cs"; do
      [[ -f "$cand" ]] && matches+=("$cand")
    done
    ;;
esac

if [[ ${#matches[@]} -gt 0 ]]; then exit 0; fi

# No test found.
echo "TDD gate: no test file found for $file" >&2
echo "  Expected one of: ${name}.test.${ext}, ${name}.spec.${ext}, test_${name}.py, ${name}_test.go ..." >&2
echo "  Add a test alongside this change (see /test-first skill), or bypass with TDD_GATE_DISABLED=1." >&2

if [[ "${TDD_GATE_BLOCK:-0}" == "1" ]]; then exit 2; fi
exit 1
