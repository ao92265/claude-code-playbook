#!/bin/bash
# .NET build checker: runs dotnet build after C# edits and returns only compiler error lines
# Hook point: PostToolUse (matcher: "Edit|Write")
# Exit codes: 0=pass or not applicable, 2=build failed (errors on stderr)
# Optional: DOTNET_BUILD_TARGET=path/to/App.sln or App.csproj (default: whatever dotnet finds in the project root)
# Adapted from Mehdi Mohseni, "Claude Code for .NET Developers" (Medium, 30 Oct 2026)

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[ -z "$FILE_PATH" ] && exit 0

# Only react to C# source files. .csproj is excluded on purpose: a written .csproj can carry an Exec target that runs code with no Bash prompt.
case "$FILE_PATH" in
  *.cs) ;;
  *) exit 0 ;;
esac

command -v dotnet >/dev/null 2>&1 || exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

# No explicit target and nothing buildable in the project root: skip silently
if [ -z "${DOTNET_BUILD_TARGET:-}" ]; then
  compgen -G "./*.sln" >/dev/null || compgen -G "./*.slnx" >/dev/null || compgen -G "./*.csproj" >/dev/null || exit 0
fi

if OUTPUT=$(dotnet build ${DOTNET_BUILD_TARGET:+"$DOTNET_BUILD_TARGET"} --no-restore -v q -nologo 2>&1); then
  exit 0
fi

ERRORS=$(echo "$OUTPUT" | grep -E "error [A-Z]+[0-9]+" | sort -u | head -20)
if [ -n "$ERRORS" ]; then
  echo "$ERRORS" >&2
else
  echo "$OUTPUT" | tail -20 >&2
fi
exit 2
