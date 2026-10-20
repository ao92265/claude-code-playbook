#!/bin/bash
# firewall.sh — PreToolUse(Bash) deny gate for irreversible/destructive commands.
# Fires regardless of permission mode (auto / bypassPermissions), so it — together
# with protect-paths.sh — is the real enforcement layer. The autoMode.hard_deny
# block in settings.json was removed once this covered its unique entries; this
# file is now the single source of truth for Bash denials.
#
# Escape hatch, the user only: relaunch with CLAUDE_SKIP_HOOKS=firewall in the
# environment, or add it to ~/.zshrc and open a new terminal. It CANNOT be set
# from inside a running session, by anyone.
SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,firewall,*) exit 0 ;; esac

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Skip if no command
[ -z "$CMD" ] && exit 0

# Strip quoted strings and heredocs so we don't match text inside commit messages etc.
# A heredoc body is skipped only when it is written somewhere inert: the << is
# outside quotes, comments and arithmetic, the delimiter ends cleanly, and no shell
# (bash, sh, ssh, eval, source, ., $SHELL ...) appears anywhere outside the bodies,
# since a body can be fed to one before or after it. An unclosed body is printed at
# the end, because bash would run those lines. If awk fails, the raw command is checked.
HD_AWK='
function scan(s, upto,   i, c, p) {
  for (i = 1; i < upto; i++) {
    c = substr(s, i, 1)
    if (sq) { if (c == "\\" && ansi) i++; else if (c == q) sq = 0; continue }
    if (c == "\\") { i++; continue }
    if (c == "$" && substr(s, i + 1, 1) == q && !dq) { sq = 1; ansi = 1; i++; continue }
    if (c == q && !dq) { sq = 1; ansi = 0; continue }
    if (c == "#" && !dq && (i == 1 || substr(s, i - 1, 1) ~ /[ \t;&|(]/)) { cm = 1; return }
    if (c == "$" && substr(s, i + 1, 1) == "(") { if (substr(s, i + 2, 1) == "(") { ar++; i += 2 } else { stk[++dep] = dq; dq = 0; i++ }; continue }
    if (c == "(" && substr(s, i + 1, 1) == "(" && !dq) { p = substr(s, 1, i - 1); sub(/[ \t]+$/, "", p); if (p == "" || p ~ /[;&|(]$/) { ar++; i++; continue } }
    if (ar && c == ")" && substr(s, i + 1, 1) == ")") { ar--; i++; continue }
    if (c == ")" && dep && !dq) { dq = stk[dep--]; continue }
    if (c == "\"") dq = !dq
  }
}
BEGIN { re = "<<-?[ \t]*([\"" q "][A-Za-z_][A-Za-z0-9_]*[\"" q "]|[A-Za-z_][A-Za-z0-9_]*)" }
skip { buf = buf $0 "\n"; t = $0; if (tabs) sub(/^\t+/, "", t); if (t == delim) { skip = 0; buf = "" }; next }
{ print
  cm = 0; s0q = sq; s0d = dq; s0a = ar; s0dep = dep; s0n = ansi
  if (!feed && match($0, re) && (substr($0, RSTART + RLENGTH, 1) == "" || substr($0, RSTART + RLENGTH, 1) ~ /[ \t;|&)>]/) \
      && !(RSTART > 1 && substr($0, RSTART - 1, 1) == "<") && substr($0, RSTART + 2, 1) != "<") {
    st = RSTART; ln = RLENGTH
    scan($0, st)
    if (!sq && !dq && !ar && !cm) {
      m = substr($0, st, ln); tabs = (m ~ /^<<-/)
      delim = m; sub(/^<<-?[ \t]*/, "", delim); gsub(/["\047]/, "", delim)
      skip = 1
    }
    sq = s0q; dq = s0d; ar = s0a; dep = s0dep; ansi = s0n
  }
  cm = 0; scan($0, length($0) + 1)
}
END { if (skip) printf "%s", buf }'
# Pass 1 drops every inert-looking body. A shell name left in what remains means a
# body may be executed, so pass 2 then keeps all bodies. A shebang inside a script
# being written does not count, because it sits in a body.
# Fast path: this hook runs on every Bash call, so skip the passes a command cannot need.
STRIPPED="$CMD"
case "$CMD" in *"<<"*)
STRIPPED=$(printf '%s\n' "$CMD" | awk -v q="'" -v feed=0 "$HD_AWK") || STRIPPED="$CMD"
if printf '%s' "$STRIPPED" | tr -d "\"'\\\\" | grep -qE '(^|[^A-Za-z0-9_.-])(bash|sh|zsh|dash|ksh|csh|tcsh|mksh|fish|ssh|eval|source|exec|xargs)([^A-Za-z0-9_.-]|$)|\$\{?SHELL|(^|[;&|( 	])\.[ 	]'; then
  STRIPPED=$(printf '%s\n' "$CMD" | awk -v q="'" -v feed=1 "$HD_AWK") || STRIPPED="$CMD"
fi
;; esac
# Remove quoted text with a quote-aware pass, so an apostrophe inside "..." cannot
# pair with a later quote and swallow the real command between them. Code inside
# "$( ... )" runs, so it is kept.
case "$STRIPPED" in *[\"\']*)
STRIPPED=$(printf '%s\n' "$STRIPPED" | awk -v q="'" '
{ out = ""
  for (i = 1; i <= length($0); i++) {
    c = substr($0, i, 1)
    if (sq) { if (c == "\\" && ansi) i++; else if (c == q) sq = 0; continue }
    if (dq) { if (c == "\\") i++; else if (c == "\"") dq = 0
              else if (c == "$" && substr($0, i + 1, 1) == "(") { stk[++dep] = 1; dq = 0; out = out " "; i++ }
              continue }
    if (c == ")" && dep) { dq = stk[dep--]; out = out " "; continue }
    if (c == "$" && substr($0, i + 1, 1) == "(") { stk[++dep] = 0; out = out "$("; i++; continue }
    if (c == "\\") { out = out c substr($0, i + 1, 1); i++; continue }
    if (c == "$" && substr($0, i + 1, 1) == q) { sq = 1; ansi = 1; i++; continue }
    if (c == q) { sq = 1; ansi = 0; continue }
    if (c == "\"") { dq = 1; continue }
    out = out c
  }
  print out }') || STRIPPED="$CMD"
;; esac

# git reset --hard: allow safe recoverable forms (remote-tracking refs, SHAs, HEAD~N),
# block bare/working-tree-clobbering forms that drop uncommitted work without reflog recovery.
if echo "$STRIPPED" | grep -qE 'git reset --hard'; then
  # Allow only reflog-recoverable targets: remote refs, HEAD~N / HEAD^ (NOT bare HEAD,
  # which clobbers uncommitted work), or a SHA.
  if ! echo "$STRIPPED" | grep -qE 'git reset --hard[[:space:]]+(origin/[A-Za-z0-9._/-]+|upstream/[A-Za-z0-9._/-]+|HEAD(~[0-9]+|\^+)|[0-9a-f]{7,40})([[:space:]]|$)'; then
    echo "BLOCKED: '$CMD' — bare 'git reset --hard' / 'reset --hard HEAD' drops uncommitted work. Use 'git reset --hard origin/<branch>', 'HEAD~N', or '<sha>' for a reflog-recoverable form." >&2
    exit 2
  fi
fi

# Irreversible data / DB / migration destroyers (case-insensitive; flag-order-agnostic clean).
if echo "$STRIPPED" | grep -qiE '(DROP[[:space:]]+TABLE|TRUNCATE[[:space:]]+TABLE|git[[:space:]]+clean[^|;&]*-[a-z]*f|(^|[[:space:]])dropdb([[:space:]]|$)|prisma[[:space:]]+migrate[[:space:]]+(deploy|reset))'; then
  echo "BLOCKED: '$CMD' — irreversible (data/db/migration). Propose a safer alternative or run it yourself outside the hook." >&2
  exit 2
fi

# Recursive-force rm (rm -rf, rm -fr, rm -r -f, rm --recursive --force, ...).
# Replaces the former autoMode hard_deny 'rm -rf *' blanket. Use a non-recursive
# form or name files explicitly. There is no in-session bypass, by design.
RM_PART=$(echo "$STRIPPED" | grep -oE '(^|[;&|[:space:]])rm[[:space:]].*' || true)
if [ -n "$RM_PART" ] \
   && echo "$RM_PART" | grep -qiE '(-[a-z]*r[a-z]*([[:space:]]|$)|--recursive)' \
   && echo "$RM_PART" | grep -qiE '(-[a-z]*f[a-z]*([[:space:]]|$)|--force)'; then
  echo "BLOCKED: '$CMD' — recursive force 'rm' is irreversible. Name an explicit target without combining -r and -f. There is no in-session bypass: prefixing the command with CLAUDE_SKIP_HOOKS=firewall does NOT work (this hook cannot see it), so do not retry that way. Only the user can disable this, by relaunching claude with that variable exported." >&2
  exit 2
fi

# Working-tree clobbers: 'git checkout .' / 'git restore .' discard uncommitted work;
# 'git branch -D' force-deletes (allow the safe 'git branch -d').
if echo "$STRIPPED" | grep -qE 'git[[:space:]]+(checkout|restore)[[:space:]]+(--[[:space:]]+)?\.([[:space:]]|$)|git[[:space:]]+branch[[:space:]]+-D([[:space:]]|$)'; then
  echo "BLOCKED: '$CMD' — discards uncommitted work or force-deletes a branch. Use a scoped path, or 'git branch -d' for a merged branch." >&2
  exit 2
fi

# Killing the shared tmux server takes every live Claude session with it (14 Oct 2026:
# a reap test set TMUX_TMPDIR but not 'unset TMUX', so kill-server hit the real server).
# Allowed only on a private server: -L/-S on the call, or 'unset TMUX' plus TMUX_TMPDIR=.
if echo "$STRIPPED" | grep -qE '(^|[;&|(`[:space:]])(pkill|killall)[[:space:]]+(-[^[:space:]]+[[:space:]]+)*tmux([[:space:]]|$)'; then
  echo "BLOCKED: '$CMD'. Killing tmux closes every live Claude session. Kill a named session with 'tmux kill-session -t <name>' instead." >&2
  exit 2
fi
if echo "$STRIPPED" | grep -qE 'tmux[^;&|]*kill-server' \
   && ! echo "$STRIPPED" | grep -qE 'tmux[[:space:]]+(-[^[:space:]]+[[:space:]]+)*-[LS][[:space:]]*[^[:space:]]+[^;&|]*kill-server' \
   && ! { echo "$STRIPPED" | grep -qE 'unset[[:space:]]+([A-Za-z_]+[[:space:]]+)*TMUX([[:space:]]|;|$)' \
          && echo "$STRIPPED" | grep -qE 'TMUX_TMPDIR='; }; then
  echo "BLOCKED: '$CMD'. Running 'tmux kill-server' here would kill the REAL tmux server and every live Claude session. For a test server, use 'tmux -L <name> kill-server', or 'unset TMUX' and set TMUX_TMPDIR first." >&2
  exit 2
fi

# Bypassing the commit/push verification gates.
# DISABLED 2026-06-19 (user request) — re-enable by uncommenting the block below.
# if echo "$STRIPPED" | grep -qE 'git[[:space:]]+(commit|push)[^|;&]*--no-verify'; then
#   echo "BLOCKED: '$CMD' — '--no-verify' skips the pre-commit/pre-push checks. Fix the underlying failure instead of bypassing." >&2
#   exit 2
# fi

# Block cloud destructives (Terraform / Azure / AWS / GCP / Kubernetes / Helm)
if echo "$STRIPPED" | grep -qE '(terraform[[:space:]]+destroy|terraform[[:space:]]+apply.*-auto-approve|az[[:space:]]+(group|vm|resource|aks|sql|storage[[:space:]]+account|keyvault|webapp|functionapp)[[:space:]]+delete|aws[[:space:]]+s3[[:space:]]+rb.*--force|aws[[:space:]]+s3[[:space:]]+rm[^|;&]*--recursive|aws[[:space:]]+(rds[[:space:]]+delete-db-instance|ec2[[:space:]]+terminate-instances|cloudformation[[:space:]]+delete-stack|iam[[:space:]]+delete)|gcloud[[:space:]]+(projects|sql[[:space:]]+instances|compute[[:space:]]+instances)[[:space:]]+delete|kubectl[[:space:]]+delete[[:space:]]+(--all|namespace|pv|pvc|cluster)|helm[[:space:]]+uninstall|docker[[:space:]]+(system[[:space:]]+prune.*-a|volume[[:space:]]+rm.*--force))'; then
  echo "BLOCKED: '$CMD' — cloud/cluster destructive. Confirm with user before running outside hook." >&2
  exit 2
fi

# Block force push (-f or --force) but allow the safe --force-with-lease variant.
if echo "$STRIPPED" | grep -qE 'git[[:space:]]+push[^|;&]*[[:space:]](-f|--force)([[:space:]]|$)' && ! echo "$STRIPPED" | grep -qE 'git[[:space:]]+push.*--force-with-lease'; then
  echo "BLOCKED: '$CMD' — force push is irreversible. Use '--force-with-lease' if you must." >&2
  exit 2
fi

# Interactive / stdin-waiting commands hang the non-interactive Bash tool.
# Block them and suggest the non-interactive form (mirrored in workflow-rules.md).
if echo "$STRIPPED" | grep -qE 'git[[:space:]]+add[[:space:]]+(-[a-zA-Z]*[pi]([[:space:]]|$)|--patch|--interactive)'; then
  echo "BLOCKED: '$CMD' — interactive 'git add' waits on stdin and hangs. Use 'git add <paths>' or 'git add -A'." >&2
  exit 2
fi
if echo "$STRIPPED" | grep -qE 'git[[:space:]]+rebase[^|;&]*[[:space:]](-i([[:space:]]|$)|--interactive)'; then
  echo "BLOCKED: '$CMD' — 'git rebase -i' opens an editor and hangs. Use a non-interactive rebase or scripted reword." >&2
  exit 2
fi
if echo "$STRIPPED" | grep -qE 'git[[:space:]]+commit([[:space:]]|$)' \
   && ! echo "$STRIPPED" | grep -qE '((^|[[:space:]])-[a-zA-Z]*m|--message|(^|[[:space:]])-[a-zA-Z]*F|--file|--no-edit|(^|[[:space:]])-[a-zA-Z]*C|--reuse-message)'; then
  echo "BLOCKED: '$CMD' — bare 'git commit' opens an editor and hangs. Pass -m \"msg\" (or --no-edit for an amend)." >&2
  exit 2
fi
if echo "$STRIPPED" | grep -qE '(^|[;&|][[:space:]]*)(vim?|nvim|nano|emacs|pico|less|more)([[:space:]]|$)'; then
  echo "BLOCKED: '$CMD' — interactive editor/pager hangs the Bash tool. Use the Read tool, or 'cat'/'sed -n' for output." >&2
  exit 2
fi
if echo "$STRIPPED" | grep -qE '(npm|yarn|pnpm)[[:space:]]+init([[:space:]]|$)' && ! echo "$STRIPPED" | grep -qE '(-y([[:space:]]|$)|--yes)'; then
  echo "BLOCKED: '$CMD' — package-manager 'init' prompts interactively. Add '-y' / '--yes'." >&2
  exit 2
fi

exit 0
