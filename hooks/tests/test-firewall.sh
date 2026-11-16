#!/bin/bash
# firewall.sh: destructive commands exit 2, safe forms exit 0.
source "$(dirname "$0")/lib.sh"
H=firewall.sh
try() { run $H "$(bash_payload "$2")"; expect "$1" "$3"; }

try "rm -rf blocked"            'rm -rf /tmp/x' 2
try "rm -fr blocked"            'rm -fr /tmp/x' 2
try "rm -r -f blocked"          'rm -r -f /tmp/x' 2
try "rm --recursive --force"    'rm --recursive --force /tmp/x' 2
try "rm single file ok"         'rm /tmp/x.txt' 0
try "rm -r alone ok"            'rm -r /tmp/x' 0
try "reset --hard bare blocked" 'git reset --hard' 2
try "reset --hard HEAD blocked" 'git reset --hard HEAD' 2
try "reset --hard origin ok"    'git reset --hard origin/main' 0
try "reset --hard HEAD~1 ok"    'git reset --hard HEAD~1' 0
try "DROP TABLE blocked"        'psql -c "x"; echo DROP TABLE users' 2
try "prisma migrate deploy blocked" 'npx prisma migrate deploy' 2
try "prisma migrate reset blocked" 'npx prisma migrate reset' 2
try "prisma generate ok" 'npx prisma generate' 0
try "git clean -fd blocked"     'git clean -fd' 2
try "checkout . blocked"        'git checkout .' 2
try "branch -D blocked"         'git branch -D feature' 2
try "branch -d ok"              'git branch -d feature' 0
try "force push blocked"        'git push --force origin main' 2
try "push -f blocked"           'git push -f origin main' 2
try "force-with-lease ok"       'git push --force-with-lease origin main' 0
try "plain push ok"             'git push origin main' 0
try "terraform destroy blocked" 'terraform destroy' 2
try "kubectl delete ns blocked" 'kubectl delete namespace prod' 2
try "pkill tmux blocked"        'pkill tmux' 2
try "tmux kill-server blocked"  'tmux kill-server' 2
try "tmux -L kill-server ok"    'tmux -L test kill-server' 0
try "git add -p blocked"        'git add -p' 2
try "git rebase -i blocked"     'git rebase -i HEAD~3' 2
try "bare git commit blocked"   'git commit' 2
try "git commit -m ok"          'git commit -m "x"' 0
try "vim blocked"               'vim file.txt' 2
try "npm init blocked"          'npm init' 2
try "npm init -y ok"            'npm init -y' 0
try "text in quotes ignored"    'git commit -m "do not rm -rf things"' 0
try "ls ok"                     'ls -la' 0
run $H '{"tool_input":{}}'; expect "empty command ok" 0
run $H "$(bash_payload 'rm -rf /tmp/x')" CLAUDE_SKIP_HOOKS=firewall; expect "skip env honoured" 0
finish
