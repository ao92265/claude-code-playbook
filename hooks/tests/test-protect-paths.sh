#!/bin/bash
# protect-paths.sh: protected files exit 2, everything else exit 0.
source "$(dirname "$0")/lib.sh"
H=protect-paths.sh
try() { run $H "$(file_payload Edit "$2")"; expect "$1" "$3"; }

try ".env blocked"              /p/.env 2
try ".env.local blocked"        /p/.env.local 2
try ".env.production blocked"   /p/.env.production 2
try "package-lock blocked"      /p/package-lock.json 2
try "yarn.lock blocked"         /p/yarn.lock 2
try "pnpm-lock blocked"         /p/pnpm-lock.yaml 2
try "prisma schema blocked"     /p/prisma/schema.prisma 2
try "prisma migration blocked"  /p/prisma/migrations/001/migration.sql 2
try "credentials.json blocked"  /p/credentials.json 2
try ".env.example allowed"      /p/.env.example 0
try "normal source allowed"     /p/src/index.ts 0
run $H '{"tool_input":{}}'; expect "no file_path allowed" 0
run $H "$(file_payload Edit /p/.env)" CLAUDE_SKIP_HOOKS=protect-paths; expect "skip env honoured" 0
finish
