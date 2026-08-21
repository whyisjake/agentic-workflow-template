#!/usr/bin/env bash
# Adds the agentic workflow template to an existing repository.
#
# Usage (run from the root of your target repo):
#   bash <(curl -fsSL https://raw.githubusercontent.com/whyisjake/agentic-workflow-template/main/scripts/setup.sh)
#
# Or clone and run locally:
#   bash /path/to/agentic-workflow-template/scripts/setup.sh
#
# Installing from a fork or a mirror:
#   Set TEMPLATE_REPO_URL to the raw base URL of the copy you want, and
#   TEMPLATE_DOCS_URL to its web URL. Both are optional.
#
#     TEMPLATE_REPO_URL=https://raw.githubusercontent.com/<owner>/<repo>/<ref> \
#       bash <(curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/<ref>/scripts/setup.sh)
#
#   Setting TEMPLATE_REPO_URL always wins, even when the script is run from a
#   clone. If the copy you want has no anonymous raw URL — a private repo, or a
#   host with no raw endpoint — clone it and run this script from that clone
#   instead; local mode never touches the network.
#
# What this does:
#   - Adds .github/ISSUE_TEMPLATE/agent-ready.md       (alongside existing templates)
#   - Adds .github/PULL_REQUEST_TEMPLATE/agent-generated.md  (alongside existing templates)
#   - Adds .github/LABELS.yml  (or prints merge instructions if one already exists)
#   - Adds .github/workflows/  (all agent workflow files, skips any that already exist)
#   - Adds .github/agents/issue-screener.agent.md
#   - Adds scripts/validate-workflows.sh  (the workflow YAML + permission guard)
#   - Adds .github/actions/claude-run/       (the shared agent invocation)
#   - Adds .github/actions/screen-issue/     (the shared issue structure check)
#   - Creates docs/ if it doesn't exist
#   - Sets the AGENT_PROVIDER repository variable, and reports on the secret
#   - Prints next steps
#
# Nothing is committed — you review and commit the changes yourself.
#
# AGENT PROVIDER:
#   AGENT_PROVIDER=claude  — choose the provider without being prompted
#   SKIP_AGENT_SETUP=1     — skip the provider section entirely
#
#   The provider's credential is never set here. Secrets are write-only and it
#   is your key, so the script reports whether it is present and tells you how
#   to add it.
#
# EXISTING TEMPLATES:
#   Issue templates coexist — GitHub shows all files in ISSUE_TEMPLATE/ as choices.
#   PR templates coexist   — GitHub shows all files in PULL_REQUEST_TEMPLATE/ as choices.
#   If you use a single flat pull_request_template.md, this script adds a named
#   PULL_REQUEST_TEMPLATE/ directory alongside it (both work at the same time).

set -euo pipefail

REPO_URL_EXPLICIT="${TEMPLATE_REPO_URL:+yes}"
REPO_URL="${TEMPLATE_REPO_URL:-https://raw.githubusercontent.com/whyisjake/agentic-workflow-template/main}"
DOCS_URL="${TEMPLATE_DOCS_URL:-https://github.com/whyisjake/agentic-workflow-template}"
TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." 2>/dev/null && pwd)" || true

# Decide where files come from once, up front, instead of per file.
#
# fetch() used to try the local clone and fall back to REPO_URL whenever a file
# was not found there. That fallback is silent: a clone that is incomplete, or a
# TEMPLATE_DIR that resolved somewhere unexpected, downloads from the hardcoded
# URL instead and the run still reports success. Deciding once means the source
# is printed before anything is written, and a broken local clone fails loudly
# rather than quietly installing someone else's copy.
if [[ "$REPO_URL_EXPLICIT" == "yes" ]]; then
  SOURCE_MODE="remote"
elif [[ -n "$TEMPLATE_DIR" && -f "$TEMPLATE_DIR/.github/workflows/agent-ready-trigger.yml" ]]; then
  SOURCE_MODE="local"
else
  SOURCE_MODE="remote"
fi

if [[ "$SOURCE_MODE" == "local" ]]; then
  SOURCE_DESC="local clone at $TEMPLATE_DIR"
  LABELS_SOURCE="$TEMPLATE_DIR/.github/LABELS.yml"
else
  SOURCE_DESC="$REPO_URL"
  LABELS_SOURCE="$REPO_URL/.github/LABELS.yml"
fi

# ── Helpers ───────────────────────────────────────────────────────────────────

green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }
dim()    { printf '\033[2m%s\033[0m\n' "$*"; }

# Copy a file from the local clone, or download it — whichever mode was chosen
# above. No fallback between the two: if the chosen source cannot supply a file,
# that is an error worth stopping on.
fetch() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ "$SOURCE_MODE" == "local" ]]; then
    if [[ ! -f "$TEMPLATE_DIR/$src" ]]; then
      red "Error: $src is missing from the template clone at $TEMPLATE_DIR"
      red "       The clone looks incomplete. Re-clone it, or set TEMPLATE_REPO_URL to install from a URL."
      exit 1
    fi
    cp "$TEMPLATE_DIR/$src" "$dest"
  else
    if ! curl -fsSL "$REPO_URL/$src" -o "$dest"; then
      red "Error: could not download $src from $REPO_URL"
      red "       If that copy is private or has no raw URL, clone it and run this script from the clone."
      exit 1
    fi
  fi
}

# ── Preflight ─────────────────────────────────────────────────────────────────

if [[ ! -d ".git" ]]; then
  red "Error: run this script from the root of a git repository."
  exit 1
fi

bold ""
bold "Agentic Workflow Template — Setup"
echo  "Adding agent-ready workflow files to: $(basename "$(pwd)")"
echo  "Installing from: $SOURCE_DESC"
echo  ""

# ── Issue template ────────────────────────────────────────────────────────────
# GitHub shows every file in ISSUE_TEMPLATE/ as a separate choice when opening
# an issue, so agent-ready.md coexists with bug_report.md, feature_request.md, etc.

if [[ -d ".github/ISSUE_TEMPLATE" ]]; then
  dim "  .github/ISSUE_TEMPLATE/ already exists — adding agent-ready.md alongside your existing templates"
fi

if [[ -f ".github/ISSUE_TEMPLATE/agent-ready.md" ]]; then
  yellow "  skipped (already exists): .github/ISSUE_TEMPLATE/agent-ready.md"
else
  fetch ".github/ISSUE_TEMPLATE/agent-ready.md" ".github/ISSUE_TEMPLATE/agent-ready.md"
  green "  added: .github/ISSUE_TEMPLATE/agent-ready.md"
fi

# ── PR template ───────────────────────────────────────────────────────────────
# GitHub supports multiple named PR templates in PULL_REQUEST_TEMPLATE/.
# If you have a flat .github/pull_request_template.md, both approaches work
# simultaneously — GitHub uses the named directory when it exists.

if [[ -f ".github/pull_request_template.md" ]]; then
  dim "  Found .github/pull_request_template.md — adding named PULL_REQUEST_TEMPLATE/ alongside it"
  dim "  (GitHub uses named templates when PULL_REQUEST_TEMPLATE/ exists; your existing template is unaffected)"
fi

if [[ -f ".github/PULL_REQUEST_TEMPLATE/agent-generated.md" ]]; then
  yellow "  skipped (already exists): .github/PULL_REQUEST_TEMPLATE/agent-generated.md"
else
  fetch ".github/PULL_REQUEST_TEMPLATE/agent-generated.md" ".github/PULL_REQUEST_TEMPLATE/agent-generated.md"
  green "  added: .github/PULL_REQUEST_TEMPLATE/agent-generated.md"
fi

# ── LABELS.yml ────────────────────────────────────────────────────────────────

if [[ -f ".github/LABELS.yml" ]]; then
  yellow "  skipped (already exists): .github/LABELS.yml"
  echo   "  → To add agent labels, append these entries to your existing LABELS.yml:"
  echo   "    $LABELS_SOURCE"
else
  fetch ".github/LABELS.yml" ".github/LABELS.yml"
  green "  added: .github/LABELS.yml"
fi

# ── Workflows ────────────────────────────────────────────────────────────────
# Each workflow file is independent — skipping an existing file leaves the
# rest unaffected.

WORKFLOW_FILES=(
  ".github/workflows/agent-ready-trigger.yml"
  ".github/workflows/plan-approval-gate.yml"
  ".github/workflows/setup-labels.yml"
  ".github/workflows/auto-label-agent-ready.yml"
  ".github/workflows/issue-screener.yml"
  ".github/workflows/validate-workflows.yml"
  ".github/workflows/claude-pr-feedback.yml"
)

for file in "${WORKFLOW_FILES[@]}"; do
  if [[ -f "$file" ]]; then
    yellow "  skipped (already exists): $file"
  else
    fetch "$file" "$file"
    green "  added: $file"
  fi
done

# ── Agent file ────────────────────────────────────────────────────────────────

if [[ -f ".github/agents/issue-screener.agent.md" ]]; then
  yellow "  skipped (already exists): .github/agents/issue-screener.agent.md"
else
  fetch ".github/agents/issue-screener.agent.md" ".github/agents/issue-screener.agent.md"
  green "  added: .github/agents/issue-screener.agent.md"
fi

# ── Composite action ──────────────────────────────────────────────────────────
# The workflows call ./.github/actions/claude-run rather than the upstream
# action directly, so the permission mode and allow list have one definition.
# A repo that gets the workflows without this directory has three workflows
# referencing an action that does not exist, and every agent run fails at
# startup — so this is not optional and is installed even if it already exists
# in some other form.

for action in claude-run screen-issue; do
  if [[ -f ".github/actions/$action/action.yml" ]]; then
    yellow "  skipped (already exists): .github/actions/$action/action.yml"
  else
    fetch ".github/actions/$action/action.yml" ".github/actions/$action/action.yml"
    green "  added: .github/actions/$action/action.yml"
  fi
done

# ── Scripts ───────────────────────────────────────────────────────────────────
# validate-workflows.sh installs alongside the workflows because both halves of
# the guard depend on it: the agent is told to run it before opening a PR, and
# validate-workflows.yml runs it in CI. Installing the workflow without the
# script would leave the guard broken in the one repo that needs it.

if [[ -f "scripts/validate-workflows.sh" ]]; then
  yellow "  skipped (already exists): scripts/validate-workflows.sh"
else
  fetch "scripts/validate-workflows.sh" "scripts/validate-workflows.sh"
  chmod +x "scripts/validate-workflows.sh"
  green "  added: scripts/validate-workflows.sh"
fi

# ── docs/ directory ───────────────────────────────────────────────────────────

if [[ ! -d "docs" ]]; then
  mkdir -p docs
  green "  created: docs/"
fi

# ── Agent provider ────────────────────────────────────────────────────────────
# Copying the files in is not enough to make the agent run. The workflows read
# AGENT_PROVIDER from repository variables and the provider's key from
# repository secrets. With neither set, labels sync and CI goes green, so the
# repo looks configured — but labelling an issue agent-ready does nothing, and
# the first sign of that is an issue that never gets a PR.
#
# So the variable gets set here, and the secret — which this script cannot set,
# because secrets are write-only and it is not our credential — gets named.

# Which secret each provider needs. Empty means the provider has no single
# credential we can check for: you wire those up yourself.
secret_for_provider() {
  case "$1" in
    claude)       printf '%s' "CLAUDE_CODE_OAUTH_TOKEN" ;;
    openai-codex) printf '%s' "OPENAI_API_KEY" ;;
    *)            printf '%s' "" ;;
  esac
}

PROVIDER_NEXT_STEP="Set AGENT_PROVIDER and your provider's secret — see the README."

echo ""
bold "Agent provider"

if [[ -n "${SKIP_AGENT_SETUP:-}" ]]; then
  dim "  SKIP_AGENT_SETUP is set — leaving AGENT_PROVIDER alone."
else
  provider="${AGENT_PROVIDER:-}"

  if [[ -z "$provider" ]]; then
    if [[ -t 0 ]]; then
      echo "  Which agent should run agent-ready issues?"
      echo "    1) claude        — the only provider implemented"
      echo "    2) openai-codex  — NOT IMPLEMENTED: a stub you must write yourself"
      echo "    3) copilot       — NOT IMPLEMENTED: a stub you must write yourself"
      echo "    4) custom        — repository_dispatch only; you write the listener"
      choice=""
      read -r -p "  Choice [1]: " choice || true
      case "${choice:-1}" in
        1|""|claude)      provider="claude" ;;
        2|openai-codex)   provider="openai-codex" ;;
        3|copilot)        provider="copilot" ;;
        4|custom)         provider="custom" ;;
        *) red "  Not one of the four choices: $choice"; exit 1 ;;
      esac
    else
      provider="claude"
      dim "  No terminal to prompt on — using claude. Set AGENT_PROVIDER to choose another."
    fi
  fi

  case "$provider" in
    claude|openai-codex|copilot|custom) ;;
    *) red "  AGENT_PROVIDER must be one of: claude, openai-codex, copilot, custom (got: $provider)"; exit 1 ;;
  esac

  # Set the repository variable. Needs gh, and a repo that exists on the remote —
  # a fresh local repo that has never been pushed has nothing to set it on.
  #
  # `gh repo view` is the probe rather than `gh auth status`: auth status
  # aggregates every configured host and exits non-zero when any one of them
  # fails, so a second host being unreachable — an enterprise host off VPN, say —
  # makes it report "not logged in" for a repo whose own host is fine. Asking
  # about this repo answers the question that actually matters.
  variable_set="no"
  if ! command -v gh >/dev/null 2>&1; then
    yellow "  gh CLI not found — AGENT_PROVIDER not set"
  elif ! gh repo view >/dev/null 2>&1; then
    yellow "  gh cannot see a GitHub repo here — AGENT_PROVIDER not set"
    dim   "  (the repo may not be pushed yet, or gh may not be logged in to its host: gh auth login)"
  elif gh variable set AGENT_PROVIDER --body "$provider" >/dev/null 2>&1; then
    green "  set: AGENT_PROVIDER=$provider"
    variable_set="yes"
  else
    yellow "  could not set AGENT_PROVIDER — your gh token may lack permission on this repo"
  fi

  if [[ "$variable_set" == "no" ]]; then
    echo "  → Set it by hand: Settings → Secrets and variables → Actions → Variables → New"
    echo "    AGENT_PROVIDER = $provider"
  fi

  # Say plainly when the chosen provider does not do anything yet.
  #
  # Only the claude path is implemented. openai-codex and copilot are stub jobs
  # that echo and exit; custom dispatches a repository_dispatch event and needs a
  # listener that does not exist yet. Either way the repo installs cleanly, syncs
  # its labels, goes green, and then produces nothing the first time someone
  # labels an issue.
  #
  # This is one of two places that says so — the stub jobs themselves now comment
  # on the issue and fail, which is the signal that reaches someone who never ran
  # this script.
  case "$provider" in
    openai-codex|copilot)
      echo ""
      red   "  '$provider' is not implemented — its job is a stub."
      echo  "  trigger-$provider in .github/workflows/agent-ready-trigger.yml echoes a"
      echo  "  message and exits without running an agent or opening a pull request."
      echo  "  Labelling an issue agent-ready under this provider will not produce a PR"
      echo  "  until you write that job yourself."
      echo  "  For a working agent, re-run with: AGENT_PROVIDER=claude bash scripts/setup.sh"
      echo ""
      PROVIDER_NEXT_STEP="Provider is $provider, which is a stub — implement trigger-$provider, or switch to claude."
      ;;
    custom)
      echo ""
      yellow "  'custom' dispatches; it does not implement."
      echo   "  trigger-custom fires a repository_dispatch 'agent-ready' event carrying the"
      echo   "  issue payload. Nothing consumes it until you add a listener workflow in THIS"
      echo   "  repository — repository_dispatch is not cross-repo."
      echo   "  For a working agent without writing one, re-run with: AGENT_PROVIDER=claude"
      echo ""
      PROVIDER_NEXT_STEP="Provider is custom — add a listener workflow for the repository_dispatch 'agent-ready' event."
      ;;
  esac

  # Report on the secret. Never set it.
  secret="$(secret_for_provider "$provider")"
  if [[ "$provider" != "claude" && -n "$secret" ]]; then
    # Name it without failing on it. trigger-openai-codex really does read
    # secrets.OPENAI_API_KEY, so staying silent here would trade one silent gap
    # for another — but the job is a stub, so a missing secret is not yet what
    # stops it working.
    dim "  Not checking for $secret — the stub never gets far enough to read it."
    dim "  You will need it once you write the job."
  elif [[ -z "$secret" ]]; then
    dim "  Provider '$provider' has no single required secret — its credentials are yours to wire up."
  else
    if [[ "$variable_set" == "yes" ]] && gh secret list 2>/dev/null | awk '{print $1}' | grep -qx "$secret"; then
      green "  found: $secret is already set"
      PROVIDER_NEXT_STEP="Provider is $provider and $secret is set — you are ready to label an issue."
    else
      red   "  missing: $secret"
      echo  "  Until it is set, labelling an issue agent-ready will not start the agent."
      echo  "  It is your credential and secrets are write-only, so this script cannot add it."
      echo  "  Add it with:  gh secret set $secret"
      echo  "  or at:        Settings → Secrets and variables → Actions → Secrets"
      PROVIDER_NEXT_STEP="Add the $secret secret — the agent cannot run without it."
    fi
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
bold "Done. Next steps:"
echo ""
echo "  1. Review added files:"
echo "     git status"
echo ""
echo "  2. Commit:"
echo "     git add .github/ docs/"
echo "     git commit -m 'chore: add agentic workflow template'"
echo "     git push"
echo ""
echo "  3. Sync labels (run once after pushing):"
echo "     Actions → Setup Labels → Run workflow"
echo ""
echo "  4. Agent provider:"
echo "     $PROVIDER_NEXT_STEP"
echo ""
echo "  5. Install the Claude GitHub App (needed as these workflows are written):"
echo "     Easiest: run /install-github-app from Claude Code — it does the app"
echo "     and the secret together, and you may have done it already."
echo "     Otherwise: https://github.com/apps/claude -> Configure -> this repo"
echo ""
echo "     Without it, runs fail in ~29 seconds on a 401 at the app token"
echo "     exchange, even though labels sync and the workflow fires."
echo ""
echo "  Full docs: $DOCS_URL"
echo ""
