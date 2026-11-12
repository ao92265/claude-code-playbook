#!/bin/bash
# .NET MSBuild write guard: allowlist with "ask". Edit/Write to anything not on the allowlist
# prompts the developer instead of running silently.
# Hook point: PreToolUse (matcher: "Edit|Write|MultiEdit|NotebookEdit")
# Exit codes: always 0. "ask" is the PreToolUse JSON on stdout (permissionDecision "ask").
# Companion to dotnet-build.sh: install both. Many files can carry code that MSBuild runs on the
# next build, and a denylist of them keeps being bypassed (lookalike Unicode names, backslash
# paths, wildcard import folders), so the default here is to ask.
# Allowed silently: inside CLAUDE_PROJECT_DIR, ASCII-only path, no .git/obj/bin/.claude/.nuget or
# msbuild/importbefore/importafter component, and an extension on the list below.
# Not covered: files written through Bash, Directory.Build.* in parent dirs, build-time code in the
# repo (analyzers, source generators, custom tasks), bypass-permissions mode. See docs/dotnet-teams.md.

ask() {
  # Static JSON, no jq needed. $1 is a fixed reason string without quotes or backslashes.
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"dotnet-msbuild-guard: %s"}}\n' "$1"
  exit 0
}

command -v jq >/dev/null 2>&1 || ask "jq not found, cannot inspect this write"

INPUT=$(cat)
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')

[ -z "$FILE_PATH" ] && exit 0

# Backslashes to slashes, then any non-ASCII or control byte means ask
P=${FILE_PATH//\\//}
if printf '%s' "$P" | LC_ALL=C grep -q '[^ -~]'; then
  ask "path has non-ASCII or control characters"
fi

command -v python3 >/dev/null 2>&1 || ask "python3 not found, cannot resolve the path"

PROJ=${CLAUDE_PROJECT_DIR:-$PWD}
# Prints the resolved path relative to the project root, or OUTSIDE. Symlinks are followed
# (the parent dir when the file is new).
REL=$(python3 -I -c '
import os, sys
proj = os.path.realpath(sys.argv[1])
p = sys.argv[2]
if not os.path.isabs(p):
    p = os.path.join(proj, p)
r = os.path.realpath(p)
if r != proj and not r.startswith(proj.rstrip("/") + "/"):
    print("OUTSIDE")
else:
    print(os.path.relpath(r, proj))
' "$PROJ" "$P" 2>/dev/null) || ask "could not resolve the path"
[ -z "$REL" ] && ask "could not resolve the path"
[ "$REL" = "OUTSIDE" ] && ask "path resolves outside the project directory"

# Components of both the given path and the resolved path (relative to the project)
LOWER=$(printf '%s\n%s' "$P" "$REL" | tr '[:upper:]' '[:lower:]')
while IFS= read -r line; do
  IFS='/' read -r -a parts <<< "$line"
  for c in "${parts[@]}"; do
    case "$c" in
      .git|obj|bin|.claude|.nuget|*msbuild*|*importbefore*|*importafter*)
        ask "a path component is a build, tooling or git location" ;;
    esac
  done
done <<< "$LOWER"

check_name() {
  local base ext
  base=$(printf '%s' "${1##*/}" | tr '[:upper:]' '[:lower:]')
  [ "$base" = "global.json" ] && ask "global.json can redirect the SDK"
  case "$base" in
    *.*) ext=".${base##*.}" ;;
    *) ext="" ;;
  esac
  case "$ext" in
    .cs|.md|.razor|.cshtml|.css|.scss|.js|.ts|.tsx|.html|.txt|.json) ;;
    *) ask "this file extension is not on the silent allowlist" ;;
  esac
}
# The resolved name and the name as given must both be allowed (a symlink can rename a file)
check_name "$REL"
check_name "$P"

exit 0
