#!/bin/bash
# dotnet-msbuild-guard.sh: allowlist with "ask". Silent only for plain source/doc files inside the project.
source "$(dirname "$0")/lib.sh"
H=dotnet-msbuild-guard.sh
P="$TD/proj"; mkdir -p "$P/src" "$P/.git" "$P/bin"; touch "$P/src/A.cs"
OUTSIDE="$TD/outside"; mkdir -p "$OUTSIDE"
ask()    { run $H "$(jq -nc --arg f "$2" '{tool_input:{file_path:$f}}')" CLAUDE_PROJECT_DIR="$P"; expect_has "$1" "$OUT" '"permissionDecision":"ask"'; expect "$1 exits 0" 0; }
silent() { run $H "$(jq -nc --arg f "$2" '{tool_input:{file_path:$f}}')" CLAUDE_PROJECT_DIR="$P"; expect "$1" 0; expect_lacks "$1 no ask" "$OUT" 'ask'; }

silent "cs inside project is silent"       "$P/src/A.cs"
silent "new md inside project is silent"   "$P/docs.md"
silent "relative cs is silent"             "src/B.cs"
ask    "csproj asks"                       "$P/src/App.csproj"
ask    "props asks"                        "$P/Directory.Build.props"
ask    "global.json asks"                  "$P/global.json"
ask    "no extension asks"                 "$P/Makefile"
ask    "outside project asks"              "$OUTSIDE/A.cs"
ask    "dotdot escape asks"                "$P/../outside/A.cs"
ask    ".git component asks"               "$P/.git/config.cs"
ask    "bin component asks"                "$P/bin/A.cs"
ask    "msbuild component asks"            "$P/MSBuild/A.cs"
ask    "non-ASCII asks"                    "$P/src/Caf$(printf '\xc3\xa9').cs"
ask    "newline in middle asks"            "$P/src/A"$'\n'"B.cs"
ask    "trailing newline asks"             "$P/src/A.cs"$'\n'
ask    "backslash path asks"               "$P\\src\\..\\..\\outside\\A.cs"
ln -s "$OUTSIDE" "$P/link"
ask    "symlink out of project asks"       "$P/link/A.cs"
ln -s "$P/src/A.cs" "$P/looks-fine.cs"; ln -sf "$P/src/App.csproj" "$P/renamed.cs" 2>/dev/null
ask    "symlink to csproj asks"            "$P/renamed.cs"

ask    "backslash .git relative asks"      '.git\hooks\x.cs'
ln -s "$P/src/A.cs" "$P/evil.csproj"
ask    "given name .csproj symlinked to cs asks" "$P/evil.csproj"

# CLAUDE_PROJECT_DIR unset: nothing can be proven inside the project, so ask.
cd "$P"   # cwd is the project: the hook must still not guess the root from it
run $H "$(jq -nc --arg f "$P/src/A.cs" '{tool_input:{file_path:$f}}')"
expect_has "CLAUDE_PROJECT_DIR unset asks" "$OUT" '"permissionDecision":"ask"'
run $H "$(jq -nc --arg f "$P/src/A.cs" '{tool_input:{file_path:$f}}')" CLAUDE_PROJECT_DIR=
expect_has "CLAUDE_PROJECT_DIR empty asks" "$OUT" '"permissionDecision":"ask"'

# Empty or missing path is a no-op; notebook_path is checked too.
run $H '{"tool_input":{}}' CLAUDE_PROJECT_DIR="$P"; expect "no path is a no-op" 0; expect_lacks "no path no ask" "$OUT" ask
run $H "$(jq -nc --arg f "$OUTSIDE/n.ipynb" '{tool_input:{notebook_path:$f}}')" CLAUDE_PROJECT_DIR="$P"
expect_has "notebook_path outside asks" "$OUT" '"permissionDecision":"ask"'
finish
