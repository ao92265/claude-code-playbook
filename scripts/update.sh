#!/bin/bash
# Claude Code Playbook — Update Installed Skills & Hooks
# Pulls the latest playbook and updates your installed skills and hooks.
# Usage: ./scripts/update.sh

set -e

REPO_URL="https://github.com/ao92265/claude-code-playbook.git"
TEMP_DIR=$(mktemp -d)
SKILLS_DIR="$HOME/.claude/skills"
HOOKS_DIR="$HOME/.claude/hooks"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

echo ""
echo -e "${BOLD}Claude Code Playbook — Updater${NC}"
echo ""

# Clone latest
echo -e "${BLUE}Fetching latest playbook...${NC}"
git clone --depth 1 --quiet "$REPO_URL" "$TEMP_DIR/playbook"
echo -e "${GREEN}Done.${NC}"
echo ""

UPDATED=0
SKIPPED=0

# Update skills
if [ -d "$SKILLS_DIR" ]; then
  echo -e "${BOLD}Updating skills...${NC}"
  for installed in "$SKILLS_DIR"/*/; do
    name=$(basename "$installed")
    if [ -d "$TEMP_DIR/playbook/skills/$name" ]; then
      # Compare and update if different
      if ! diff -q "$installed/SKILL.md" "$TEMP_DIR/playbook/skills/$name/SKILL.md" >/dev/null 2>&1; then
        cp -r "$TEMP_DIR/playbook/skills/$name/"* "$installed/"
        echo -e "  ${GREEN}Updated:${NC} $name"
        UPDATED=$((UPDATED + 1))
      else
        SKIPPED=$((SKIPPED + 1))
      fi
    fi
  done
else
  echo -e "${YELLOW}No skills directory found at $SKILLS_DIR${NC}"
fi
echo ""

# Update hooks
if [ -d "$HOOKS_DIR" ]; then
  echo -e "${BOLD}Updating hooks...${NC}"
  for installed in "$HOOKS_DIR"/*.sh; do
    name=$(basename "$installed")
    if [ -f "$TEMP_DIR/playbook/hooks/$name" ]; then
      if ! diff -q "$installed" "$TEMP_DIR/playbook/hooks/$name" >/dev/null 2>&1; then
        cp "$TEMP_DIR/playbook/hooks/$name" "$installed"
        chmod +x "$installed"
        echo -e "  ${GREEN}Updated:${NC} $name"
        UPDATED=$((UPDATED + 1))
      else
        SKIPPED=$((SKIPPED + 1))
      fi
    fi
  done
else
  echo -e "${YELLOW}No hooks directory found at $HOOKS_DIR${NC}"
fi
echo ""

# Check for new skills not yet installed
echo -e "${BOLD}New skills available:${NC}"
NEW_COUNT=0
for available in "$TEMP_DIR/playbook/skills"/*/; do
  name=$(basename "$available")
  if [ ! -d "$SKILLS_DIR/$name" ]; then
    echo -e "  ${BLUE}New:${NC} /$name — $(head -5 "$available/SKILL.md" | grep 'name:' | sed 's/name: //')"
    NEW_COUNT=$((NEW_COUNT + 1))
  fi
done
if [ $NEW_COUNT -eq 0 ]; then
  echo -e "  ${DIM}All available skills are installed.${NC}"
fi
echo ""

# Summary
echo -e "${BOLD}Summary${NC}"
echo "  Updated: $UPDATED"
echo "  Already current: $SKIPPED"
echo "  New available: $NEW_COUNT"
echo ""

# Cleanup
rm -rf "$TEMP_DIR"
