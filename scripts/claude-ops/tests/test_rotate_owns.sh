#!/bin/bash
# session-rotate.sh owns(): a reboot file belongs to a session only when it names
# that session's exact folder. The old match was a substring, so /x/foo also
# claimed a handoff written for /x/foo-bar and cleared the wrong work.
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$HERE/session-rotate.sh"
FAIL=0
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

# Pull just the helpers out of the script; running it would touch tmux.
eval "$(awk '/^has_path\(\)/,/^}/' "$SCRIPT")"
eval "$(awk '/^owns\(\)/,/^}/' "$SCRIPT")"

mk() { printf '%s\n' "$1" > "$T/f.md"; }
want() { # want <0|1> <label> <file text> <MAP_CWD>
  MAP_CWD="$4"; mk "$3"; owns "$T/f.md"; got=$?
  [ "$got" -eq "$1" ] && echo "OK   $2" || { echo "FAIL $2 (want $1 got $got)"; FAIL=$((FAIL+1)); }
}

want 0 "exact folder in backticks"            '- Path: `/x/foo`'                   /x/foo
want 0 "exact folder at end of line"         '- Path: /x/foo'                     /x/foo
want 0 "session folder inside a longer path"  '- Path: `/x/foo/sub/dir`'           /x/foo
want 1 "longer sibling name is not a match"   '- Path: `/x/foo-bar`'               /x/foo
want 1 "name with a suffix is not a match"    '- Path: `/x/foo2`'                  /x/foo
want 1 "dotted sibling is not a match"        '- Path: `/x/foo.bak`'               /x/foo
want 1 "same name under another parent"       '- Path: `/y/x/foo`'                 /x/foo
want 0 "file names both folders"              "$(printf '/x/foo-bar\n/x/foo\n')"   /x/foo
want 0 "private spelling in the file"         '- Path: `/private/tmp/foo`'         /tmp/foo
want 0 "private spelling in the map"          '- Path: `/tmp/foo`'                 /private/tmp/foo
want 1 "private sibling is not a match"       '- Path: `/private/tmp/foo-bar`'     /tmp/foo
want 0 "empty map folder owns everything"     '- Path: `/anything`'                ""
want 0 "folder name with a backslash matches" '- Path: `/x/a\tb`'                  '/x/a\tb'
want 1 "backslash folder does not match a sibling" '- Path: `/x/a\tb2`'            '/x/a\tb'

[ "$FAIL" -eq 0 ]
