#!/bin/bash
# Claude Code Playbook — Interactive Installer
# Usage: curl -sL https://raw.githubusercontent.com/ao92265/claude-code-playbook/main/scripts/install.sh | bash
# Or: ./scripts/install.sh

set -e

REPO_URL="https://github.com/ao92265/claude-code-playbook.git"
TEMP_DIR=$(mktemp -d)
CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"
HOOKS_DIR="$CLAUDE_DIR/hooks"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   Claude Code Playbook — Installer       ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
if ! command -v git &> /dev/null; then
  echo -e "${RED}Error: git is not installed.${NC}"
  exit 1
fi

# Clone repo
echo -e "${BLUE}Cloning playbook...${NC}"
git clone --depth 1 --quiet "$REPO_URL" "$TEMP_DIR/playbook"
echo -e "${GREEN}Done.${NC}"
echo ""

# Ensure directories exist
mkdir -p "$SKILLS_DIR" "$HOOKS_DIR"

# ─── CLAUDE.md Template ────────────────────────────────────────────
echo -e "${BOLD}CLAUDE.md Templates${NC}"
echo ""
echo "  Available templates:"
echo "    1) General / TypeScript"
echo "    2) React / Next.js"
echo "    3) Node.js API"
echo "    4) Python"
echo "    5) Full-stack monorepo"
echo "    6) Go"
echo "    7) Rust"
echo "    8) React Native / Mobile"
echo "    9) DevOps / Infrastructure"
echo "    0) Skip"
echo ""
read -rp "  Choose a template to copy to current directory [0-9]: " tmpl_choice

case $tmpl_choice in
  1) cp "$TEMP_DIR/playbook/templates/CLAUDE.md" ./CLAUDE.md ;;
  2) cp "$TEMP_DIR/playbook/templates/CLAUDE-react.md" ./CLAUDE.md ;;
  3) cp "$TEMP_DIR/playbook/templates/CLAUDE-node-api.md" ./CLAUDE.md ;;
  4) cp "$TEMP_DIR/playbook/templates/CLAUDE-python.md" ./CLAUDE.md ;;
  5) cp "$TEMP_DIR/playbook/templates/CLAUDE-fullstack.md" ./CLAUDE.md ;;
  6) cp "$TEMP_DIR/playbook/templates/CLAUDE-go.md" ./CLAUDE.md ;;
  7) cp "$TEMP_DIR/playbook/templates/CLAUDE-rust.md" ./CLAUDE.md ;;
  8) cp "$TEMP_DIR/playbook/templates/CLAUDE-mobile.md" ./CLAUDE.md ;;
  9) cp "$TEMP_DIR/playbook/templates/CLAUDE-devops.md" ./CLAUDE.md ;;
  0|"") echo "  Skipped." ;;
  *) echo "  Invalid choice. Skipped." ;;
esac

if [ "$tmpl_choice" != "0" ] && [ -n "$tmpl_choice" ] && [ "$tmpl_choice" -ge 1 ] 2>/dev/null && [ "$tmpl_choice" -le 9 ] 2>/dev/null; then
  echo -e "  ${GREEN}Copied to ./CLAUDE.md${NC}"
fi
echo ""

# ─── Skills ─────────────────────────────────────────────────────────
echo -e "${BOLD}Skills${NC} (installed globally to ~/.claude/skills/)"
echo ""
echo "  Available skill packs:"
echo "    1) Essential   — check-env, deploy, verification-before-completion, handoff"
echo "    2) Quality     — test-first, refactor, code-review, security-check, dependency-audit"
echo "    3) Planning    — writing-plans, executing-plans, brainstorming, karpathy-guidelines"
echo "    4) All skills  — everything"
echo "    0) Skip"
echo ""
read -rp "  Choose a skill pack [0-4]: " skill_choice

install_skill() {
  local name="$1"
  if [ -d "$TEMP_DIR/playbook/skills/$name" ]; then
    cp -r "$TEMP_DIR/playbook/skills/$name" "$SKILLS_DIR/"
    echo -e "    ${GREEN}+${NC} $name"
  fi
}

case $skill_choice in
  1)
    for s in check-env deploy verification-before-completion handoff; do install_skill "$s"; done
    ;;
  2)
    for s in test-first refactor code-review security-check dependency-audit; do install_skill "$s"; done
    ;;
  3)
    for s in writing-plans executing-plans brainstorming karpathy-guidelines; do install_skill "$s"; done
    ;;
  4)
    for s in "$TEMP_DIR/playbook/skills"/*/; do
      name=$(basename "$s")
      install_skill "$name"
    done
    ;;
  0|"") echo "  Skipped." ;;
  *) echo "  Invalid choice. Skipped." ;;
esac
echo ""

# ─── Hooks ──────────────────────────────────────────────────────────
echo -e "${BOLD}Hooks${NC} (installed to ~/.claude/hooks/)"
echo ""
echo "  Available hooks:"
echo "    1) TypeScript  — ts-check.sh, lint-check.sh, build-check.sh"
echo "    2) Safety      — pre-commit-guard.sh, env-guard.sh"
echo "    3) Formatting  — format-check.sh"
echo "    4) All hooks"
echo "    0) Skip"
echo ""
read -rp "  Choose a hook pack [0-4]: " hook_choice

install_hook() {
  local name="$1"
  if [ -f "$TEMP_DIR/playbook/hooks/$name" ]; then
    cp "$TEMP_DIR/playbook/hooks/$name" "$HOOKS_DIR/"
    chmod +x "$HOOKS_DIR/$name"
    echo -e "    ${GREEN}+${NC} $name"
  fi
}

case $hook_choice in
  1)
    for h in ts-check.sh lint-check.sh build-check.sh; do install_hook "$h"; done
    ;;
  2)
    for h in pre-commit-guard.sh env-guard.sh; do install_hook "$h"; done
    ;;
  3)
    install_hook "format-check.sh"
    ;;
  4)
    for h in "$TEMP_DIR/playbook/hooks"/*.sh; do
      name=$(basename "$h")
      install_hook "$name"
    done
    ;;
  0|"") echo "  Skipped." ;;
  *) echo "  Invalid choice. Skipped." ;;
esac
echo ""

# ─── Summary ────────────────────────────────────────────────────────
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   Installation Complete                   ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "  Installed to:"
echo "    Skills: $SKILLS_DIR/"
echo "    Hooks:  $HOOKS_DIR/"
if [ -f ./CLAUDE.md ]; then
  echo "    Template: ./CLAUDE.md"
fi
echo ""
echo -e "  ${YELLOW}Next steps:${NC}"
echo "    1. Edit ./CLAUDE.md to match your project conventions"
echo "    2. Add hooks to ~/.claude/settings.json (see hooks/README.md)"
echo "    3. Start a Claude Code session and try: /check-env"
echo ""
echo -e "  ${BLUE}Docs:${NC} https://github.com/ao92265/claude-code-playbook"
echo ""

# Cleanup
rm -rf "$TEMP_DIR"
