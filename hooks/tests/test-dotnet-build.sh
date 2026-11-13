#!/bin/bash
# dotnet-build.sh: builds after a .cs edit only when it is safe; a stub dotnet records each call.
source "$(dirname "$0")/lib.sh"
H=dotnet-build.sh
STUB="$TD/stub"; mkdir -p "$STUB"
cat > "$STUB/dotnet" <<'STUBEOF'
#!/bin/bash
echo "$*" >> "$MARKER"
[ "${STUB_RC:-0}" = 0 ] || echo "Program.cs(1,1): error CS1002: ; expected [App.csproj]"
exit "${STUB_RC:-0}"
STUBEOF
chmod +x "$STUB/dotnet"
MARKER="$TD/marker"

newrepo() { # fresh git repo with one committed .cs file and a built obj/
  P="$TD/p$RANDOM"; mkdir -p "$P/obj"; cd "$P" || exit 1
  git init -q . && git config user.email t@t && git config user.name t
  echo 'class A {}' > A.cs; echo '<Project/>' > App.csproj
  printf 'obj/\n*.user\n' > .gitignore
  git add -A && git commit -qm init
  echo '{}' > obj/project.assets.json
  rm -f "$MARKER"
}
build() { # <cs-path> [extra env...]
  run $H "$(jq -nc --arg f "$1" '{tool_input:{file_path:$f}}')" PATH="$STUB:$PATH" CLAUDE_PROJECT_DIR="$P" MARKER="$MARKER" "${@:2}"
}
built() { [ -f "$MARKER" ]; }
expect_built()   { if built; then pass=$((pass+1)); echo "ok   $1"; else fail=$((fail+1)); echo "FAIL $1 (no build)"; fi; }
expect_skipped() { if built; then fail=$((fail+1)); echo "FAIL $1 (built)"; else pass=$((pass+1)); echo "ok   $1"; fi; }

newrepo; echo 'class A { int x; }' > A.cs
build "$P/A.cs" DOTNET_BUILD_TARGET=App.csproj
expect "only .cs changed: exit 0" 0; expect_built "only .cs changed: builds"
expect_has "build gets the target" "$(cat "$MARKER")" "build App.csproj"
for w in BeforeMicrosoftCommonProps AfterMicrosoftCommonProps BeforeMicrosoftCommonTargets AfterMicrosoftCommonTargets; do
  expect_has "build disables wildcard import $w" "$(cat "$MARKER")" "-p:ImportUserLocationsByWildcard$w=false"
done

newrepo; echo 'class A { int x; }' > A.cs; echo '<Project>x</Project>' > App.csproj
build "$P/A.cs" DOTNET_BUILD_TARGET=App.csproj
expect "csproj changed too: exit 0" 0; expect_skipped "non-.cs change skips build"
expect_has "skip reason names the file" "$ERR" "App.csproj"

newrepo; echo 'class A { int x; }' > A.cs; echo '<Project/>' > new.props
build "$P/A.cs" DOTNET_BUILD_TARGET=App.csproj; expect_skipped "untracked non-.cs file skips build"

newrepo; echo 'class A { int x; }' > A.cs; echo '# n' > notes.md
build "$P/A.cs" DOTNET_BUILD_TARGET=App.csproj; expect_built ".cs plus .md still builds"

newrepo; echo 'class A { int x; }' > A.cs
sleep 1; touch App.csproj.user
build "$P/A.cs" DOTNET_BUILD_TARGET=App.csproj
expect "*.user newer: exit 0" 0; expect_skipped "*.user newer than assets skips build"
expect_has "user skip reason" "$ERR" "*.user"

newrepo; echo 'class A { int x; }' > A.cs; touch -t 202001010000 App.csproj.user
build "$P/A.cs" DOTNET_BUILD_TARGET=App.csproj; expect_built "*.user older than assets still builds"

newrepo; echo 'class A { int x; }' > A.cs; sleep 1; echo '<P/>' > obj/evil.targets
build "$P/A.cs" DOTNET_BUILD_TARGET=App.csproj; expect_skipped "obj targets newer than assets skips build"

newrepo; echo 'class A { int x; }' > A.cs; rm obj/project.assets.json; echo '<P/>' > obj/evil.props
build "$P/A.cs" DOTNET_BUILD_TARGET=App.csproj; expect_skipped "obj props without assets skips build"

newrepo; echo 'class A { int x; }' > A.cs
build "$P/A.cs"
expect "DOTNET_BUILD_TARGET unset: exit 0" 0; expect_skipped "DOTNET_BUILD_TARGET unset skips build"
expect_has "unset target says so" "$ERR" "DOTNET_BUILD_TARGET not set"
build "$P/A.cs" DOTNET_BUILD_TARGET=
expect_skipped "DOTNET_BUILD_TARGET empty skips build"

newrepo; echo '# n' > notes.md
build "$P/notes.md" DOTNET_BUILD_TARGET=App.csproj; expect "non-.cs edited file: exit 0" 0; expect_skipped "non-.cs edited file skips build"
run $H '{"tool_input":{}}' PATH="$STUB:$PATH" MARKER="$MARKER"; expect "no file_path: exit 0" 0

newrepo; echo 'class A { int x; }' > A.cs
build "$P/A.cs" DOTNET_BUILD_TARGET=App.csproj STUB_RC=1
expect "failed build exits 2" 2; expect_has "failed build shows compiler error" "$ERR" "error CS1002"

D="$TD/nogit"; mkdir -p "$D"; echo 'class A {}' > "$D/A.cs"; rm -f "$MARKER"
run $H "$(jq -nc --arg f "$D/A.cs" '{tool_input:{file_path:$f}}')" PATH="$STUB:$PATH" CLAUDE_PROJECT_DIR="$D" MARKER="$MARKER" DOTNET_BUILD_TARGET=App.csproj
expect "not a git repo: exit 0" 0; expect_skipped "not a git repo skips build"
finish
