#!/usr/bin/env bash
# Adds the agentic workflow template to an existing repository.
#
# Usage (run from the root of your target repo):
#   bash <(curl -fsSL https://raw.githubusercontent.com/whyisjake/agentic-workflow-template/main/scripts/setup.sh)
#
# Or clone and run locally:
#   bash /path/to/agentic-workflow-template/scripts/setup.sh
#
# What this does:
#   - Copies .github/ISSUE_TEMPLATE/agent-ready.md
#   - Copies .github/PULL_REQUEST_TEMPLATE/agent-generated.md
#   - Copies .github/LABELS.yml  (merges — does not overwrite existing content)
#   - Copies .github/workflows/  (all agent workflow files)
#   - Copies .github/agents/issue-screener.agent.md
#   - Creates docs/ if it doesn't exist
#   - Prints next steps
#
# Nothing is committed — you review and commit the changes yourself.

set -euo pipefail

REPO_URL="https://raw.githubusercontent.com/whyisjake/agentic-workflow-template/main"
TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." 2>/dev/null && pwd)" || true

# ── Helpers ──────────────────────────────────────────────────────────────────

green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }

# Download a file from the template repo, or copy from local clone
fetch() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"

  if [[ -n "$TEMPLATE_DIR" && -f "$TEMPLATE_DIR/$src" ]]; then
    cp "$TEMPLATE_DIR/$src" "$dest"
  else
    curl -fsSL "$REPO_URL/$src" -o "$dest"
  fi
}

# ── Preflight ─────────────────────────────────────────────────────────────────

if [[ ! -d ".git" ]]; then
  red "Error: run this script from the root of a git repository."
  exit 1
fi

bold ""
bold "Agentic Workflow Template — Setup"
echo  "Adding agent-ready workflow files to $(basename "$(pwd)")"
echo  ""

# ── Copy files ────────────────────────────────────────────────────────────────

FILES=(
  ".github/ISSUE_TEMPLATE/agent-ready.md"
  ".github/PULL_REQUEST_TEMPLATE/agent-generated.md"
  ".github/workflows/agent-ready-trigger.yml"
  ".github/workflows/plan-approval-gate.yml"
  ".github/workflows/setup-labels.yml"
  ".github/workflows/auto-label-agent-ready.yml"
  ".github/workflows/issue-screener.yml"
  ".github/agents/issue-screener.agent.md"
)

SKIPPED=()

for file in "${FILES[@]}"; do
  if [[ -f "$file" ]]; then
    yellow "  skipped (already exists): $file"
    SKIPPED+=("$file")
  else
    fetch "$file" "$file"
    green "  added: $file"
  fi
done

# LABELS.yml: merge rather than overwrite if it already exists
if [[ -f ".github/LABELS.yml" ]]; then
  yellow "  skipped (already exists): .github/LABELS.yml"
  yellow "  → Manually merge agent labels from:"
  yellow "    $REPO_URL/.github/LABELS.yml"
  SKIPPED+=(".github/LABELS.yml")
else
  fetch ".github/LABELS.yml" ".github/LABELS.yml"
  green "  added: .github/LABELS.yml"
fi

# Create docs/ if it doesn't exist (workflows write plans there)
if [[ ! -d "docs" ]]; then
  mkdir -p docs
  green "  created: docs/"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
bold "Done."
echo ""

if [[ ${#SKIPPED[@]} -gt 0 ]]; then
  yellow "Some files were skipped because they already exist:"
  for f in "${SKIPPED[@]}"; do yellow "  - $f"; done
  echo ""
fi

bold "Next steps:"
echo ""
echo "  1. Review the added files with: git diff --stat"
echo ""
echo "  2. Commit the changes:"
echo "     git add .github/ docs/"
echo "     git commit -m 'chore: add agentic workflow template'"
echo ""
echo "  3. Push and sync labels — run the Setup Labels workflow:"
echo "     Actions → Setup Labels → Run workflow"
echo ""
echo "  4. Set your agent provider (optional, defaults to claude):"
echo "     Settings → Secrets and variables → Variables → AGENT_PROVIDER"
echo ""
echo "  5. Add your agent secret:"
echo "     Settings → Secrets and variables → Secrets → CLAUDE_CODE_OAUTH_TOKEN"
echo ""
echo "  Full docs: https://github.com/whyisjake/agentic-workflow-template"
echo ""
