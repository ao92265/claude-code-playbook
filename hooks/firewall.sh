#!/bin/bash
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Skip if no command
[ -z "$CMD" ] && exit 0

# Strip quoted strings and heredocs so we don't match text inside commit messages etc.
STRIPPED=$(echo "$CMD" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g" | sed '/<<.*EOF/,/EOF/d')

# Block irreversible/dangerous commands (local + cloud)
# git reset --hard: allow safe recoverable forms (remote-tracking refs, SHAs, HEAD~N),
# block bare/working-tree-clobbering forms that drop uncommitted work without reflog recovery.
if echo "$STRIPPED" | grep -qE 'git reset --hard'; then
  if ! echo "$STRIPPED" | grep -qE 'git reset --hard[[:space:]]+(origin/[A-Za-z0-9._/-]+|upstream/[A-Za-z0-9._/-]+|HEAD(~[0-9]+|\^+)?|[0-9a-f]{7,40})([[:space:]]|$)'; then
    echo "BLOCKED: '$CMD' — bare 'git reset --hard' can drop uncommitted work. Use 'git reset --hard origin/<branch>' or '<sha>' for reflog-recoverable form." >&2
    exit 2
  fi
fi

if echo "$STRIPPED" | grep -qE '(rm -rf /|DROP TABLE|TRUNCATE TABLE|git clean -fd)'; then
  echo "BLOCKED: '$CMD' — this command is irreversible. Propose a safer alternative." >&2
  exit 2
fi

# Block cloud destructives (Terraform / Azure / AWS / GCP / Kubernetes / Helm)
if echo "$STRIPPED" | grep -qE '(terraform[[:space:]]+destroy|terraform[[:space:]]+apply.*-auto-approve|az[[:space:]]+(group|vm|resource|aks|sql|storage[[:space:]]+account|keyvault|webapp|functionapp)[[:space:]]+delete|aws[[:space:]]+s3[[:space:]]+rb.*--force|aws[[:space:]]+(rds[[:space:]]+delete-db-instance|ec2[[:space:]]+terminate-instances|cloudformation[[:space:]]+delete-stack|iam[[:space:]]+delete)|gcloud[[:space:]]+(projects|sql[[:space:]]+instances|compute[[:space:]]+instances)[[:space:]]+delete|kubectl[[:space:]]+delete[[:space:]]+(--all|namespace|pv|pvc|cluster)|helm[[:space:]]+uninstall|docker[[:space:]]+(system[[:space:]]+prune.*-a|volume[[:space:]]+rm.*--force))'; then
  echo "BLOCKED: '$CMD' — cloud/cluster destructive. Confirm with user before running outside hook." >&2
  exit 2
fi

# Block --force push but allow the safe --force-with-lease variant
if echo "$STRIPPED" | grep -qE 'git push.*(--force)' && ! echo "$STRIPPED" | grep -qE 'git push.*--force-with-lease'; then
  echo "BLOCKED: '$CMD' — this command is irreversible. Propose a safer alternative." >&2
  exit 2
fi

exit 0
