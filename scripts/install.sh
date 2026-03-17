#!/bin/bash
# Claude Code Playbook — Installer
#
# Interactive:  ./scripts/install.sh
# Non-interactive (installs everything):
#   curl -sL https://raw.githubusercontent.com/ao92265/claude-code-playbook/main/scripts/install.sh | bash
#   ./scripts/install.sh --all
#   ./scripts/install.sh --all --template react

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
DIM='\033[2m'
NC='\033[0m'

# ─── Parse Arguments ────────────────────────────────────────────────

AUTO_MODE=false
TEMPLATE_ARG=""

# Auto-detect: if stdin is not a terminal, we're piped (curl | bash)
if [ ! -t 0 ]; then
  AUTO_MODE=true
fi

# Parse flags
while [[ $# -gt 0 ]]; do
  case $1 in
    --all) AUTO_MODE=true; shift ;;
    --template)
      TEMPLATE_ARG="$2"; shift 2 ;;
    --template=*)
      TEMPLATE_ARG="${1#*=}"; shift ;;
    --help|-h)
      echo "Usage: install.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --all                Install all skills and hooks (non-interactive)"
      echo "  --template NAME      Choose template: general, react, node, python,"
      echo "                       fullstack, go, rust, mobile, devops, java, csharp"
      echo "  -h, --help           Show this help"
      echo ""
      echo "Examples:"
      echo "  ./install.sh                          # Interactive mode"
      echo "  ./install.sh --all                    # Install everything"
      echo "  ./install.sh --all --template react   # Everything + React template"
      echo "  curl -sL URL/install.sh | bash        # Auto-installs everything"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ─── Header ─────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   Claude Code Playbook — Installer       ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""

if $AUTO_MODE; then
  echo -e "${BLUE}Running in auto mode — installing all skills and hooks.${NC}"
  [ -n "$TEMPLATE_ARG" ] && echo -e "${BLUE}Template: $TEMPLATE_ARG${NC}"
  echo ""
fi

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

# ─── Helper: resolve template name to file ──────────────────────────

resolve_template() {
  case "$1" in
    general|typescript|ts) echo "CLAUDE.md" ;;
    react|nextjs) echo "CLAUDE-react.md" ;;
    node|api|express) echo "CLAUDE-node-api.md" ;;
    python|py) echo "CLAUDE-python.md" ;;
    fullstack|monorepo) echo "CLAUDE-fullstack.md" ;;
    go|golang) echo "CLAUDE-go.md" ;;
    rust) echo "CLAUDE-rust.md" ;;
    mobile|react-native|rn) echo "CLAUDE-mobile.md" ;;
    devops|terraform|docker) echo "CLAUDE-devops.md" ;;
    java|spring) echo "CLAUDE-java.md" ;;
    csharp|dotnet|cs) echo "CLAUDE-csharp.md" ;;
    *) echo "" ;;
  esac
}

# ─── Helper: install skill ──────────────────────────────────────────

install_skill() {
  local name="$1"
  if [ -d "$TEMP_DIR/playbook/skills/$name" ]; then
    cp -r "$TEMP_DIR/playbook/skills/$name" "$SKILLS_DIR/"
    echo -e "    ${GREEN}+${NC} $name"
  fi
}

# ─── Helper: install hook ───────────────────────────────────────────

install_hook() {
  local name="$1"
  if [ -f "$TEMP_DIR/playbook/hooks/$name" ]; then
    cp "$TEMP_DIR/playbook/hooks/$name" "$HOOKS_DIR/"
    chmod +x "$HOOKS_DIR/$name"
    echo -e "    ${GREEN}+${NC} $name"
  fi
}

# ═══════════════════════════════════════════════════════════════════
# AUTO MODE — install everything without prompts
# ═══════════════════════════════════════════════════════════════════

if $AUTO_MODE; then

  # Template
  if [ -n "$TEMPLATE_ARG" ]; then
    TMPL_FILE=$(resolve_template "$TEMPLATE_ARG")
    if [ -n "$TMPL_FILE" ] && [ -f "$TEMP_DIR/playbook/templates/$TMPL_FILE" ]; then
      cp "$TEMP_DIR/playbook/templates/$TMPL_FILE" ./CLAUDE.md
      echo -e "${BOLD}Template${NC}"
      echo -e "  ${GREEN}Copied${NC} $TMPL_FILE → ./CLAUDE.md"
      echo ""
    else
      echo -e "${YELLOW}Unknown template '$TEMPLATE_ARG'. Skipping. Use --help to see options.${NC}"
      echo ""
    fi
  else
    # Copy general template if no CLAUDE.md exists
    if [ ! -f ./CLAUDE.md ]; then
      cp "$TEMP_DIR/playbook/templates/CLAUDE.md" ./CLAUDE.md
      echo -e "${BOLD}Template${NC}"
      echo -e "  ${GREEN}Copied${NC} General template → ./CLAUDE.md"
      echo ""
    else
      echo -e "${BOLD}Template${NC}"
      echo -e "  ${DIM}CLAUDE.md already exists — skipping (use --template to override)${NC}"
      echo ""
    fi
  fi

  # All skills
  echo -e "${BOLD}Installing all skills...${NC}"
  for s in "$TEMP_DIR/playbook/skills"/*/; do
    name=$(basename "$s")
    install_skill "$name"
  done
  echo ""

  # All hooks
  echo -e "${BOLD}Installing all hooks...${NC}"
  for h in "$TEMP_DIR/playbook/hooks"/*.sh; do
    name=$(basename "$h")
    install_hook "$name"
  done
  echo ""

  # Copy settings if none exists
  if [ ! -f "$CLAUDE_DIR/settings.json" ]; then
    cp "$TEMP_DIR/playbook/config/settings-full.json" "$CLAUDE_DIR/settings.json"
    echo -e "${BOLD}Settings${NC}"
    echo -e "  ${GREEN}Copied${NC} settings-full.json → ~/.claude/settings.json"
    echo ""
  else
    echo -e "${BOLD}Settings${NC}"
    echo -e "  ${DIM}~/.claude/settings.json already exists — not overwriting${NC}"
    echo -e "  ${DIM}See config/settings-full.json for the recommended hook configuration${NC}"
    echo ""
  fi

# ═══════════════════════════════════════════════════════════════════
# INTERACTIVE MODE — prompt the user for choices
# ═══════════════════════════════════════════════════════════════════

else

  # ─── CLAUDE.md Template ────────────────────────────────────────
  echo -e "${BOLD}CLAUDE.md Templates${NC}"
  echo ""
  echo "  Available templates:"
  echo "     1) General / TypeScript"
  echo "     2) React / Next.js"
  echo "     3) Node.js API"
  echo "     4) Python"
  echo "     5) Full-stack monorepo"
  echo "     6) Go"
  echo "     7) Rust"
  echo "     8) React Native / Mobile"
  echo "     9) DevOps / Infrastructure"
  echo "    10) Java / Spring Boot"
  echo "    11) C# / .NET"
  echo "     0) Skip"
  echo ""
  read -rp "  Choose a template to copy to current directory [0-11]: " tmpl_choice

  case $tmpl_choice in
    1)  cp "$TEMP_DIR/playbook/templates/CLAUDE.md" ./CLAUDE.md ;;
    2)  cp "$TEMP_DIR/playbook/templates/CLAUDE-react.md" ./CLAUDE.md ;;
    3)  cp "$TEMP_DIR/playbook/templates/CLAUDE-node-api.md" ./CLAUDE.md ;;
    4)  cp "$TEMP_DIR/playbook/templates/CLAUDE-python.md" ./CLAUDE.md ;;
    5)  cp "$TEMP_DIR/playbook/templates/CLAUDE-fullstack.md" ./CLAUDE.md ;;
    6)  cp "$TEMP_DIR/playbook/templates/CLAUDE-go.md" ./CLAUDE.md ;;
    7)  cp "$TEMP_DIR/playbook/templates/CLAUDE-rust.md" ./CLAUDE.md ;;
    8)  cp "$TEMP_DIR/playbook/templates/CLAUDE-mobile.md" ./CLAUDE.md ;;
    9)  cp "$TEMP_DIR/playbook/templates/CLAUDE-devops.md" ./CLAUDE.md ;;
    10) cp "$TEMP_DIR/playbook/templates/CLAUDE-java.md" ./CLAUDE.md ;;
    11) cp "$TEMP_DIR/playbook/templates/CLAUDE-csharp.md" ./CLAUDE.md ;;
    0|"") echo "  Skipped." ;;
    *) echo "  Invalid choice. Skipped." ;;
  esac

  if [ "$tmpl_choice" != "0" ] && [ -n "$tmpl_choice" ] && [ "$tmpl_choice" -ge 1 ] 2>/dev/null && [ "$tmpl_choice" -le 11 ] 2>/dev/null; then
    echo -e "  ${GREEN}Copied to ./CLAUDE.md${NC}"
  fi
  echo ""

  # ─── Skills ────────────────────────────────────────────────────
  echo -e "${BOLD}Skills${NC} (installed globally to ~/.claude/skills/)"
  echo ""
  echo "  Available skill packs:"
  echo "    1) Essential   — check-env, deploy, verification-before-completion, handoff"
  echo "    2) Quality     — test-first, refactor, code-review, security-check, dependency-audit"
  echo "    3) Planning    — writing-plans, executing-plans, brainstorming, karpathy-guidelines"
  echo "    4) All skills  — everything (27 skills)"
  echo "    0) Skip"
  echo ""
  read -rp "  Choose a skill pack [0-4]: " skill_choice

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

  # ─── Hooks ─────────────────────────────────────────────────────
  echo -e "${BOLD}Hooks${NC} (installed to ~/.claude/hooks/)"
  echo ""
  echo "  Available hooks:"
  echo "    1) TypeScript  — ts-check.sh, lint-check.sh, build-check.sh"
  echo "    2) Safety      — pre-commit-guard.sh, env-guard.sh, commit-message-check.sh"
  echo "    3) Formatting  — format-check.sh"
  echo "    4) Testing     — test-on-save.sh"
  echo "    5) All hooks   — everything (9 hooks)"
  echo "    0) Skip"
  echo ""
  read -rp "  Choose a hook pack [0-5]: " hook_choice

  case $hook_choice in
    1)
      for h in ts-check.sh lint-check.sh build-check.sh; do install_hook "$h"; done
      ;;
    2)
      for h in pre-commit-guard.sh env-guard.sh commit-message-check.sh; do install_hook "$h"; done
      ;;
    3)
      install_hook "format-check.sh"
      ;;
    4)
      install_hook "test-on-save.sh"
      ;;
    5)
      for h in "$TEMP_DIR/playbook/hooks"/*.sh; do
        name=$(basename "$h")
        install_hook "$name"
      done
      ;;
    0|"") echo "  Skipped." ;;
    *) echo "  Invalid choice. Skipped." ;;
  esac
  echo ""

fi

# ─── Summary ────────────────────────────────────────────────────────

SKILL_COUNT=$(ls -d "$SKILLS_DIR"/*/ 2>/dev/null | wc -l | tr -d ' ')
HOOK_COUNT=$(ls "$HOOKS_DIR"/*.sh 2>/dev/null | wc -l | tr -d ' ')

echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   Installation Complete                   ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "  Installed:"
echo "    Skills: $SKILL_COUNT in $SKILLS_DIR/"
echo "    Hooks:  $HOOK_COUNT in $HOOKS_DIR/"
if [ -f ./CLAUDE.md ]; then
  echo "    Template: ./CLAUDE.md"
fi
echo ""
echo -e "  ${YELLOW}Next steps:${NC}"
echo "    1. Edit ./CLAUDE.md to match your project conventions"
if [ ! -f "$CLAUDE_DIR/settings.json" ] || ! grep -q "hooks" "$CLAUDE_DIR/settings.json" 2>/dev/null; then
  echo "    2. Add hooks to ~/.claude/settings.json"
  echo "       (copy from config/settings-full.json in the playbook repo)"
else
  echo "    2. Hooks are configured in ~/.claude/settings.json"
fi
echo "    3. Start a Claude Code session and try: /check-env"
echo ""
echo -e "  ${BLUE}Docs:${NC} https://github.com/ao92265/claude-code-playbook"
echo ""

# Cleanup
rm -rf "$TEMP_DIR"
