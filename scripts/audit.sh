#!/bin/bash
# Claude Code Playbook — Project Audit
# Scans your project and recommends which skills, hooks, and templates to install.
# Usage: ./scripts/audit.sh [project-path]

set -e

PROJECT_DIR="${1:-.}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   Claude Code Playbook — Project Audit   ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${DIM}Scanning: $(cd "$PROJECT_DIR" && pwd)${NC}"
echo ""

# ─── Detect Stack ───────────────────────────────────────────────────

STACK=""
TEMPLATE=""
SKILLS_RECOMMENDED=()
HOOKS_RECOMMENDED=()

# TypeScript / JavaScript
if [ -f "$PROJECT_DIR/tsconfig.json" ]; then
  STACK="TypeScript"
  HOOKS_RECOMMENDED+=("ts-check.sh" "lint-check.sh" "build-check.sh")

  # React / Next.js
  if grep -q '"react"' "$PROJECT_DIR/package.json" 2>/dev/null; then
    if grep -q '"next"' "$PROJECT_DIR/package.json" 2>/dev/null; then
      STACK="React / Next.js (TypeScript)"
      TEMPLATE="CLAUDE-react.md"
    else
      STACK="React (TypeScript)"
      TEMPLATE="CLAUDE-react.md"
    fi
  # Node.js API
  elif grep -q '"express"\|"fastify"\|"koa"\|"hapi"' "$PROJECT_DIR/package.json" 2>/dev/null; then
    STACK="Node.js API (TypeScript)"
    TEMPLATE="CLAUDE-node-api.md"
  else
    TEMPLATE="CLAUDE.md"
  fi
elif [ -f "$PROJECT_DIR/package.json" ]; then
  STACK="JavaScript"
  HOOKS_RECOMMENDED+=("lint-check.sh")
  TEMPLATE="CLAUDE.md"
fi

# Python
if [ -f "$PROJECT_DIR/pyproject.toml" ] || [ -f "$PROJECT_DIR/setup.py" ] || [ -f "$PROJECT_DIR/requirements.txt" ]; then
  STACK="Python"
  TEMPLATE="CLAUDE-python.md"
fi

# Go
if [ -f "$PROJECT_DIR/go.mod" ]; then
  STACK="Go"
  TEMPLATE="CLAUDE-go.md"
fi

# Rust
if [ -f "$PROJECT_DIR/Cargo.toml" ]; then
  STACK="Rust"
  TEMPLATE="CLAUDE-rust.md"
fi

# Java / Spring
if [ -f "$PROJECT_DIR/pom.xml" ] || [ -f "$PROJECT_DIR/build.gradle" ] || [ -f "$PROJECT_DIR/build.gradle.kts" ]; then
  STACK="Java / Spring"
  TEMPLATE="CLAUDE-java.md"
fi

# C# / .NET
if ls "$PROJECT_DIR"/*.csproj 1>/dev/null 2>&1 || ls "$PROJECT_DIR"/*.sln 1>/dev/null 2>&1; then
  STACK="C# / .NET"
  TEMPLATE="CLAUDE-csharp.md"
fi

# React Native
if grep -q '"react-native"' "$PROJECT_DIR/package.json" 2>/dev/null; then
  STACK="React Native (Mobile)"
  TEMPLATE="CLAUDE-mobile.md"
fi

# Docker / DevOps
if [ -f "$PROJECT_DIR/Dockerfile" ] || [ -f "$PROJECT_DIR/docker-compose.yml" ] || [ -f "$PROJECT_DIR/terraform" ]; then
  if [ -z "$STACK" ]; then
    STACK="DevOps / Infrastructure"
    TEMPLATE="CLAUDE-devops.md"
  fi
  SKILLS_RECOMMENDED+=("docker-check")
fi

# Monorepo detection
if [ -f "$PROJECT_DIR/lerna.json" ] || [ -f "$PROJECT_DIR/nx.json" ] || [ -f "$PROJECT_DIR/turbo.json" ]; then
  STACK="Full-stack monorepo"
  TEMPLATE="CLAUDE-fullstack.md"
fi

# ─── Detect Existing Setup ──────────────────────────────────────────

HAS_CLAUDE_MD="no"
HAS_SKILLS="no"
HAS_HOOKS="no"

[ -f "$PROJECT_DIR/CLAUDE.md" ] && HAS_CLAUDE_MD="yes"
[ -d "$PROJECT_DIR/.claude/skills" ] && HAS_SKILLS="yes"
[ -d "$HOME/.claude/hooks" ] && HAS_HOOKS="yes"

# ─── Detect Needs ───────────────────────────────────────────────────

# Always recommend these
SKILLS_RECOMMENDED+=("check-env" "handoff" "code-review")

# Testing
if [ -f "$PROJECT_DIR/jest.config.js" ] || [ -f "$PROJECT_DIR/jest.config.ts" ] || [ -f "$PROJECT_DIR/vitest.config.ts" ] || [ -f "$PROJECT_DIR/pytest.ini" ] || [ -f "$PROJECT_DIR/pyproject.toml" ]; then
  SKILLS_RECOMMENDED+=("test-first")
fi

# Database
if grep -rq "prisma\|typeorm\|sequelize\|knex\|migrations\|alembic\|flyway" "$PROJECT_DIR" --include="*.json" --include="*.toml" --include="*.xml" --include="*.gradle" 2>/dev/null | head -1 >/dev/null 2>&1; then
  SKILLS_RECOMMENDED+=("migrate-db")
fi

# CI/CD or deployment
if [ -d "$PROJECT_DIR/.github/workflows" ] || [ -f "$PROJECT_DIR/.gitlab-ci.yml" ] || [ -f "$PROJECT_DIR/Jenkinsfile" ]; then
  SKILLS_RECOMMENDED+=("deploy")
fi

# Security
SKILLS_RECOMMENDED+=("security-check" "dependency-audit")

# Git
if git -C "$PROJECT_DIR" rev-parse 2>/dev/null; then
  BRANCH_COUNT=$(git -C "$PROJECT_DIR" branch | wc -l | tr -d ' ')
  if [ "$BRANCH_COUNT" -gt 10 ]; then
    SKILLS_RECOMMENDED+=("git-cleanup")
  fi
fi

# Planning
SKILLS_RECOMMENDED+=("writing-plans" "debug" "explain")

# Always recommend these hooks
HOOKS_RECOMMENDED+=("pre-commit-guard.sh" "env-guard.sh" "format-check.sh" "session-start-check.sh")

# ─── Report ─────────────────────────────────────────────────────────

echo -e "${BOLD}Stack Detected${NC}"
if [ -n "$STACK" ]; then
  echo -e "  ${GREEN}$STACK${NC}"
else
  echo -e "  ${YELLOW}Could not auto-detect. Using general template.${NC}"
  TEMPLATE="CLAUDE.md"
fi
echo ""

echo -e "${BOLD}Current Setup${NC}"
echo -e "  CLAUDE.md:  $([ "$HAS_CLAUDE_MD" = "yes" ] && echo -e "${GREEN}Found${NC}" || echo -e "${RED}Missing${NC} — add one!")"
echo -e "  Skills:     $([ "$HAS_SKILLS" = "yes" ] && echo -e "${GREEN}Found${NC}" || echo -e "${YELLOW}None installed${NC}")"
echo -e "  Hooks:      $([ "$HAS_HOOKS" = "yes" ] && echo -e "${GREEN}Found${NC}" || echo -e "${YELLOW}None installed${NC}")"
echo ""

echo -e "${BOLD}Recommended Template${NC}"
echo -e "  ${BLUE}templates/$TEMPLATE${NC}"
if [ "$HAS_CLAUDE_MD" = "no" ]; then
  echo -e "  ${DIM}cp templates/$TEMPLATE $PROJECT_DIR/CLAUDE.md${NC}"
fi
echo ""

echo -e "${BOLD}Recommended Skills${NC}"
# Deduplicate
UNIQUE_SKILLS=($(echo "${SKILLS_RECOMMENDED[@]}" | tr ' ' '\n' | sort -u))
for skill in "${UNIQUE_SKILLS[@]}"; do
  echo -e "  ${GREEN}+${NC} /$(echo "$skill" | sed 's/\.sh$//')"
done
echo ""
echo -e "  ${DIM}Install all: cp -r skills/{$(IFS=,; echo "${UNIQUE_SKILLS[*]}")} ~/.claude/skills/${NC}"
echo ""

echo -e "${BOLD}Recommended Hooks${NC}"
UNIQUE_HOOKS=($(echo "${HOOKS_RECOMMENDED[@]}" | tr ' ' '\n' | sort -u))
for hook in "${UNIQUE_HOOKS[@]}"; do
  echo -e "  ${GREEN}+${NC} $hook"
done
echo ""
echo -e "  ${DIM}Install: cp hooks/*.sh ~/.claude/hooks/ && chmod +x ~/.claude/hooks/*.sh${NC}"
echo ""

echo -e "${BOLD}Next Steps${NC}"
echo "  1. Copy the recommended template to your project as CLAUDE.md"
echo "  2. Install the recommended skills globally"
echo "  3. Install hooks and add to ~/.claude/settings.json"
echo "  4. Start a session and run /check-env"
echo ""
echo -e "  ${BLUE}Full guide:${NC} https://github.com/ao92265/claude-code-playbook"
echo ""
