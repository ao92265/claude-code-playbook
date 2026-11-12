#!/bin/bash
# .NET build checker: runs dotnet build after C# edits and returns only compiler error lines
# Hook point: PostToolUse (matcher: "Edit|Write")
# Exit codes: 0=pass or not applicable, 2=build failed (errors on stderr)
# Required: DOTNET_BUILD_TARGET=path/to/App.sln or App.csproj. With it unset the build is skipped,
#   so auto-detection can never pick up a project the model just created.
# MUST be installed together with hooks/dotnet-msbuild-guard.sh (PreToolUse), which is the real
# control: it denies Edit/Write to MSBuild/NuGet files. The checks below are a second layer only.
# The guard covers Edit/Write/MultiEdit/NotebookEdit, not files written through Bash, so keep Bash
# on "ask" (not auto or bypass) in repos using this hook. Committing a build file is a human review step.
# Directory.Build.* files in parent directories outside the repo are not covered.
# Adapted from Mehdi Mohseni, "Claude Code for .NET Developers" (Medium, 30 Oct 2026)

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[ -z "$FILE_PATH" ] && exit 0

case "$FILE_PATH" in
  *.cs) ;;
  *) exit 0 ;;
esac

command -v dotnet >/dev/null 2>&1 || exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

if [ -z "${DOTNET_BUILD_TARGET:-}" ]; then
  echo "dotnet-build: DOTNET_BUILD_TARGET not set, build skipped" >&2
  exit 0
fi

# Layer 2a: allowlist. Skip if any new or changed file is not a .cs or .md file, if a directory
# entry is collapsed or a submodule is dirty (both are not .cs/.md), or if this is not a git repo.
skip_reason=""
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  skip_reason="not a git repo"
else
  next_is_origin=0
  while IFS= read -r -d '' rec; do
    if [ "$next_is_origin" = 1 ]; then
      path="$rec"; next_is_origin=0
    else
      xy="${rec:0:2}"; path="${rec:3}"
      case "$xy" in *R*|*C*) next_is_origin=1 ;; esac
    fi
    case "$path" in
      */) skip_reason="collapsed directory entry $path"; break ;;
      *.cs|*.md) ;;
      *) skip_reason="changed file $path"; break ;;
    esac
  done < <(git status --porcelain=v1 -z --untracked-files=all 2>/dev/null)
fi
if [ -n "$skip_reason" ]; then
  echo "dotnet-build: build skipped ($skip_reason); review and commit it first" >&2
  exit 0
fi

# Layer 2b: gitignored obj/ props/targets run on build. Skip if any is newer than its
# project.assets.json, or sits in an obj/ with no project.assets.json.
while IFS= read -r objdir; do
  if [ ! -f "$objdir/project.assets.json" ]; then
    if [ -n "$(find "$objdir" -maxdepth 1 \( -name '*.props' -o -name '*.targets' \) -print -quit)" ]; then
      echo "dotnet-build: build skipped (props/targets in $objdir without project.assets.json)" >&2
      exit 0
    fi
  elif [ -n "$(find "$objdir" -maxdepth 1 \( -name '*.props' -o -name '*.targets' \) -newer "$objdir/project.assets.json" -print -quit)" ]; then
    echo "dotnet-build: build skipped (props/targets in $objdir newer than project.assets.json)" >&2
    exit 0
  fi
done < <(find . -type d -name obj -not -path '*/node_modules/*' 2>/dev/null)

if OUTPUT=$(dotnet build "$DOTNET_BUILD_TARGET" --no-restore -v q -nologo 2>&1); then
  exit 0
fi

ERRORS=$(echo "$OUTPUT" | grep -E "error [A-Z]+[0-9]+" | sort -u | head -20)
if [ -n "$ERRORS" ]; then
  echo "$ERRORS" >&2
else
  echo "$OUTPUT" | tail -20 >&2
fi
exit 2
