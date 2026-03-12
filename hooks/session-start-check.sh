#!/bin/bash
# Session start check: validates environment when a Claude Code session begins
# Hook point: SessionStart
# Exit codes: 0=pass (always passes, just reports status)

echo "=== Environment Check ==="

# Git status
BRANCH=$(git branch --show-current 2>/dev/null || echo "not a git repo")
DIRTY=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
echo "Git: branch=$BRANCH, uncommitted files=$DIRTY"

# GitHub credentials
if command -v gh &>/dev/null; then
  gh auth status &>/dev/null && echo "GitHub: authenticated" || echo "GitHub: NOT authenticated — run 'gh auth login'"
fi

# Port check
PORTS_IN_USE=""
for PORT in 3000 3001 5173 8080 8000; do
  PID=$(lsof -ti :$PORT 2>/dev/null)
  [ -n "$PID" ] && PORTS_IN_USE="$PORTS_IN_USE $PORT(pid:$PID)"
done
[ -n "$PORTS_IN_USE" ] && echo "Ports in use:$PORTS_IN_USE" || echo "Ports: all clear (3000, 3001, 5173, 8080, 8000)"

# Docker
if command -v docker &>/dev/null; then
  if docker info &>/dev/null 2>&1; then
    CONTAINERS=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')
    echo "Docker: running, $CONTAINERS container(s) active"
  else
    echo "Docker: installed but daemon not running"
  fi
fi

# Node.js
NODE_V=$(node --version 2>/dev/null || echo "not installed")
echo "Node: $NODE_V"

# .env check
[ -f ".env" ] && echo "Environment: .env found" || echo "Environment: no .env file"

echo "==========================="
exit 0
