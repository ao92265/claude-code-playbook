---
name: check-env
description: >
  Pre-flight environment check before starting dev work. Use when starting a new session
  or before spinning up dev servers. Checks Docker, ports, .env files, Node.js, and git
  status. Triggers: "check env", "check environment", "pre-flight check", "check my setup".

  Do NOT use this skill for: code changes, debugging logic, writing tests, or mid-session
  work where infrastructure is already confirmed running.
metadata:
  user-invocable: true
  slash-command: /check-env
  proactive: false
title: "Check Environment"
parent: Skills & Extensibility
---
# Check Environment

Pre-flight environment check before starting dev work. Run this at the start of a session to avoid wasting time on infrastructure issues.

## Steps

1. Check for running Docker containers that might conflict:
   - `docker ps` to list running containers
   - Flag any containers using common ports (3000, 3001, 5432, 1433, 8080)

2. Check for port conflicts on common dev ports:
   - `lsof -i :3000,3001,5432,1433,8080 2>/dev/null` to find processes using these ports
   - Report what's using each occupied port

3. Verify environment files exist:
   - Check for `.env` or `.env.local` in the current project
   - Warn if missing but don't expose contents

4. Check Docker daemon is running (if project uses Docker):
   - `docker info > /dev/null 2>&1` to verify Docker is available

5. Check Node.js and npm/yarn availability:
   - `node --version` and `npm --version`

6. Verify git status and credentials:
   - `git status` to show current branch and any uncommitted changes
   - `gh auth status` to verify GitHub credentials work
   - Test push access: `git ls-remote origin HEAD` to confirm remote connectivity

7. Check available memory for builds:
   - Report current Node.js version and default heap size
   - Recommend `NODE_OPTIONS='--max-old-space-size=4096'` if project has large builds

8. Report a clean summary of findings with any issues flagged clearly.

## Important
- Do NOT start fixing issues automatically — report them and ask what to do
- Do NOT expose .env file contents
