#!/bin/bash
SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,tdd-gate,*) exit 0 ;; esac
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
shopt -s nullglob
# macOS ships bash 3.2, which has no globstar, so tests/**/x only matches one
# folder down there. The explicit tests/x candidates below cover the top level.
shopt -s globstar 2>/dev/null || true
case "$ext" in
  ts|tsx|js|jsx|mjs|cjs)
    for cand in \
      "$dir/$name.test.$ext" "$dir/$name.spec.$ext" \
      "$dir/__tests__/$name.test.$ext" "$dir/__tests__/$name.spec.$ext" \
      tests/"$name".test.* tests/"$name".spec.* \
      tests/**/"$name".test.* tests/**/"$name".spec.* \
      test/"$name".test.* test/"$name".spec.* \
      test/**/"$name".test.* test/**/"$name".spec.*; do
      [[ -f "$cand" ]] && matches+=("$cand")
    done
    ;;
  py)
    for cand in "$dir/test_$name.py" tests/"test_$name.py" tests/"${name}_test.py" \
      tests/**/"test_$name.py" tests/**/"${name}_test.py"; do
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
  # find, not **, because macOS bash 3.2 has no globstar and these test trees
  # are usually several folders deep.
  # Start from the edited file's repo, not the hook's folder. A failing find
  # (no such folder, unreadable folder) must not end the hook under set -e, or
  # block mode would quietly turn into exit 1.
  java|kt)
    d="$dir"
    while [[ ! -d "$d" && "$d" != "/" && "$d" != "." ]]; do d="$(dirname "$d")"; done
    root="$(git -C "$d" rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -z "$root" ]]; then root="$PWD"; [[ "$d" == "$PWD"/* ]] || root="$d"; fi
    tdir="$root/src/test"
    [[ "$file" == */src/main/* ]] && tdir="${file%/src/main/*}/src/test"
    cand=$(find "$tdir" -type f \( -name "${name}Test.$ext" -o -name "${name}Tests.$ext" \) 2>/dev/null | head -1 || true)
    [[ -n "$cand" ]] && matches+=("$cand")
    ;;
  cs)
    # Inside a git repo, ask git: it is fast, scoped to this checkout (nested
    # worktrees are separate repos and are not listed), and includes new test
    # files that are not committed yet. The hook has a short timeout, and a
    # timed-out hook does not block.
    d="$dir"
    while [[ ! -d "$d" && "$d" != "/" && "$d" != "." ]]; do d="$(dirname "$d")"; done
    root="$(git -C "$d" rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -n "$root" ]]; then
      cand=$(git -C "$root" ls-files --cached --others --exclude-standard -- "*${name}Tests.cs" "*${name}.Tests.cs" 2>/dev/null | head -1 || true)
    else
      # Not in a repo: a shallow, pruned search, so a big folder cannot stall the hook.
      base="$PWD"; [[ "$d" == "$PWD"/* ]] || base="$d"
      cand=$(find "$base" -maxdepth 3 \( -name bin -o -name obj -o -name node_modules -o -name .git -o -name .claude -o -name .worktrees -o -name worktrees \) -prune -o \
        -type f \( -name "${name}Tests.cs" -o -name "${name}.Tests.cs" \) -print 2>/dev/null | head -1 || true)
    fi
    [[ -n "$cand" ]] && matches+=("$cand")
    ;;
esac

if [[ ${#matches[@]} -gt 0 ]]; then exit 0; fi

# No test found. Log the firing (ISO date, repo dir, target file, action) so
# gate effectiveness can be audited later.
action="warn"
if [[ "${TDD_GATE_BLOCK:-0}" == "1" ]]; then action="block"; fi
log_dir="${HOME}/.claude/hooks/.omc"
mkdir -p "$log_dir" 2>/dev/null || true
repo_dir="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
printf '%s\t%s\t%s\t%s\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)" "$repo_dir" "$file" "$action" \
  >> "$log_dir/tdd-gate.log" 2>/dev/null || true

echo "TDD gate: no test file found for $file" >&2
echo "  Expected one of: ${name}.test.${ext}, ${name}.spec.${ext}, test_${name}.py, ${name}_test.go ..." >&2
echo "  Add a test alongside this change (see /test-first skill), or bypass with TDD_GATE_DISABLED=1." >&2
# Prove the red is real. Measured 17 Aug 2026 in the Superpowers trial: the run's
# first "failing test" was the test runner erroring, not the assertion. A missing
# module, an import error or a broken runner is NOT red, and a fix written against
# it produces a test that has never once guarded the behaviour it claims to.
echo "  When you do write the test: run it and read WHY it failed. Red means your" >&2
echo "  assertion failed. A missing module, import error, syntax error or runner" >&2
echo "  crash is not red. Prove the real failure first, then write the fix." >&2

if [[ "${TDD_GATE_BLOCK:-0}" == "1" ]]; then exit 2; fi
exit 1
