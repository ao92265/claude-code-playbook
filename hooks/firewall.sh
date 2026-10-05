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
STRIPPED=$(echo "$CMD" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g" | sed '/<<.*EOF/,/EOF/d')

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
