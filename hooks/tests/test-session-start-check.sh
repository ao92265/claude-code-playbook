#!/bin/bash
# session-start-check.sh: SessionStart environment report (git, gh auth, ports, docker, node, .env). Always exits 0.
source "$(dirname "$0")/lib.sh"
H=session-start-check.sh
W="$TD/w"; mkdir -p "$W" "$TD/bin"; cd "$W" || exit 1
stub() { printf '#!/bin/bash\n%s\n' "$2" > "$TD/bin/$1"; chmod +x "$TD/bin/$1"; }
stub gh 'exit 0'
stub lsof 'exit 0'
stub docker '[ "$1" = info ] && exit 1; exit 0'
stub node 'echo v99.0.0'
PATHX="PATH=$TD/bin:$PATH"
chk() { run $H '' "$PATHX" "$@"; }

chk;                                      expect "check exits 0" 0
expect_has "not a repo reported" "$OUT" "branch=not a git repo"
expect_has "gh authenticated" "$OUT" "GitHub: authenticated"
expect_has "ports clear" "$OUT" "Ports: all clear"
expect_has "docker daemon down" "$OUT" "installed but daemon not running"
expect_has "node version shown" "$OUT" "Node: v99.0.0"
expect_has "no .env reported" "$OUT" "no .env file"

git init -q -b feat-q .; echo x > f.txt; touch .env
stub gh 'exit 1'
stub lsof '[ "$2" = ":3000" ] && echo 4242; exit 0'
stub docker 'if [ "$1" = info ]; then exit 0; fi; printf "a\nb\n"'
chk;                                      expect "second check exits 0" 0
expect_has "branch shown" "$OUT" "branch=feat-q"
expect_has "dirty count shown" "$OUT" "uncommitted files=2"
expect_has "gh not authenticated" "$OUT" "NOT authenticated"
expect_has "busy port reported" "$OUT" "3000(pid:4242)"
expect_has "docker containers counted" "$OUT" "2 container(s) active"
expect_has ".env found" "$OUT" ".env found"
finish
