#!/bin/bash
# .NET MSBuild write guard: denies Edit/Write to files MSBuild evaluates or generates
# Hook point: PreToolUse (matcher: "Edit|Write|MultiEdit|NotebookEdit")
# Exit codes: 0=allowed, 2=denied (reason on stderr)
# Companion to dotnet-build.sh: install both. Those files can carry an Exec target that runs on
# the next build, so the real control is refusing the write, not inspecting the tree afterwards.
# Also denied: .gitignore and anything under .git/ (they could hide a payload from the build hook's git check).
# Scope: covers Edit/Write/MultiEdit/NotebookEdit only. Files written through Bash are NOT covered,
# so keep Bash on "ask" (not auto or bypass) in repos that use this hook.
# Directory.Build.* files in parent directories outside the repo are not covered either.
# Changing a build file is a human review step: make the edit yourself, then commit it.

command -v jq >/dev/null 2>&1 || { echo "dotnet-msbuild-guard: jq not found, write denied (fail closed)" >&2; exit 2; }

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')

[ -z "$FILE_PATH" ] && exit 0

# Case-insensitive match on the lowercased path
LOWER=$(printf '%s' "$FILE_PATH" | tr '[:upper:]' '[:lower:]')
BASE="${LOWER##*/}"

deny() {
  echo "dotnet-msbuild-guard: write to $FILE_PATH denied. MSBuild/NuGet files, .gitignore, .git/ and obj/ bin/ contents can run code on the next build or hide it. Ask the developer to make this change and commit it." >&2
  exit 2
}

case "$BASE" in
  *.csproj|*.fsproj|*.vbproj|*.[a-z]*proj|*.user|*.sln|*.slnx|*.slnf|*.props|*.targets|*.tasks|*.projitems|*.rsp) deny ;;
  directory.build.*|nuget.config|global.json|.gitignore) deny ;;
esac

case "/$LOWER" in
  */obj/*|*/bin/*|*/.git/*) deny ;;
esac

exit 0
