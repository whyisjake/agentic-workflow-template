# Agentic Workflow Template

A GitHub template repository that brings structured, agent-assisted development to any codebase. Drop it into your repository to get issue templates, automated labeling, and AI agent workflows that route to **Claude Code**, **OpenAI Codex**, **GitHub Copilot**, or a **custom agent** — all configured with a single repository variable.

Built on the workflow developed at [Pew Research Center](https://pewresearch.org) and generalized for any team.

---

## How It Works

1. A developer opens an issue using the **Agent-Ready template**
2. When the issue has all the required sections, the auto-labeler flags it `agent-ready` — a hint that it looks ready, not a trigger
3. A human adds `agent-ready` (or re-applies it), and the trigger workflow routes to your configured AI agent
4. The agent implements the feature and opens a PR
5. A human reviews and merges

For `complexity:high` issues, Claude + Compound Engineering runs a planning phase first — generating a structured implementation plan that a human approves before any code is written.

---

## Quickstart (5 minutes)

**New repo** — Click **Use this template** → **Create a new repository** on GitHub.

**Existing repo** — Run the setup script from your repo root:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/whyisjake/agentic-workflow-template/main/scripts/setup.sh)
```

This copies all workflow files, skips anything that already exists, and prints next steps. Nothing is committed — you review first.

**Installing from a fork or a mirror** — the script prints which source it is using before it writes anything. To point it at a different copy, set `TEMPLATE_REPO_URL` to that copy's raw base URL:

```bash
TEMPLATE_REPO_URL=https://raw.githubusercontent.com/<owner>/<repo>/<ref> \
  bash <(curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/<ref>/scripts/setup.sh)
```

If the copy you want is private or its host has no raw endpoint, clone it and run `scripts/setup.sh` from that clone — local mode reads the files off disk and never fetches over the network.

---

**Step 1 — Enable the template flag** *(new repos only)*

Settings → General → check "Template repository".

**Step 2 — Sync labels**

Run the label sync workflow once to create all agent workflow labels in your repo:

```
Actions → Setup Labels → Run workflow
```

**Step 3 — Configure your agent**

`scripts/setup.sh` asks which provider you want and sets the `AGENT_PROVIDER` repository variable for you. Skip the prompt with `AGENT_PROVIDER=claude`, or skip the whole step with `SKIP_AGENT_SETUP=1`. Setting up by hand: `Settings → Secrets and variables → Actions → Variables`.

| Value | Status | Required secret |
|-------|--------|-----------------|
| `claude` (default) | Implemented | `CLAUDE_CODE_OAUTH_TOKEN` |
| `openai-codex` | **Not implemented** — stub job | `OPENAI_API_KEY`, once you write the job |
| `copilot` | **Not implemented** — stub job | _(gh-aw setup required — see docs)_ |
| `custom` | `repository_dispatch` only | _(your own listener — see docs)_ |

Only `claude` runs an agent today. The `openai-codex` and `copilot` jobs echo a message and exit; `custom` fires a `repository_dispatch` event that does nothing until you add a listener workflow in the same repo. Either way a repo configured for one of them installs cleanly and goes green while labelling an issue produces nothing. `setup.sh` says so when you pick one, and the run itself now fails rather than passing quietly.

If `AGENT_PROVIDER` is not set, the workflow defaults to `claude`.

**The secret is yours to add.** Secrets are write-only, so no script can set one for you — `setup.sh` reports whether it is there and stops short of claiming you are done without it. This matters because nothing else complains: labels sync, CI goes green, and the repo looks configured, but labelling an issue `agent-ready` will not start the agent. Add it with `gh secret set CLAUDE_CODE_OAUTH_TOKEN`, or at `Settings → Secrets and variables → Actions → Secrets`.

**Step 4 — Open an agent-ready issue**

Use the **Agent-Ready Task** issue template. Fill in all sections, add a `complexity:` label, then **add `agent-ready` yourself** — that label is what starts the agent.

The auto-labeler cannot start it for you. It applies `agent-ready` to issues that have the right shape, but a label applied by a workflow uses `GITHUB_TOKEN`, and GitHub does not start workflow runs from events triggered by that token. Treat its label as a review hint, not a trigger.

**Only a collaborator with write access can start a run.** The trigger checks who applied the label and stops if they do not have it. This is the security boundary that matters: an agent run holds a write-scoped token and takes the issue body as instructions, so anyone who can start one can direct it. Someone without write access can still open and describe an issue — they just cannot fire the agent themselves.

Add the complexity label **before** `agent-ready`. The trigger reads the issue's labels from the API rather than from the event, so order no longer decides routing — but an issue that reaches the agent with no complexity label takes the direct path, and a `complexity:high` issue is meant to plan first.

---

## Provider Details

| Provider | Status | Notes |
|----------|--------|-------|
| **Claude + Compound Engineering** | Implemented | Complexity-aware: high issues plan first, low/medium execute directly |
| **OpenAI Codex** | **Not implemented** — stub job | Write `trigger-openai-codex` in `.github/workflows/agent-ready-trigger.yml` |
| **GitHub Copilot (gh-aw)** | **Not implemented** — stub job | Write `trigger-copilot`; requires `gh aw compile` setup |
| **Custom** | `repository_dispatch` only | Dispatches the issue payload; wire your own listener in the same repo |

---

## What's Included

```
.github/
├── ISSUE_TEMPLATE/
│   └── agent-ready.md          # Structured issue template for agent execution
├── PULL_REQUEST_TEMPLATE/
│   └── agent-generated.md      # PR template for agent-created PRs
├── LABELS.yml                  # 7 labels for the agent workflow
├── agents/
│   └── issue-screener.agent.md # Claude-powered issue screener (opt-in)
└── workflows/
    ├── agent-ready-trigger.yml  # Core: routes labeled issues to your agent
    ├── plan-approval-gate.yml   # /approve-plan comment listener (high complexity)
    ├── setup-labels.yml         # One-time label import
    ├── auto-label-agent-ready.yml # Auto-applies agent-ready to complete issues
    └── issue-screener.yml       # Weekly screener for unscreened issues
```

---

## Labels

| Label | Purpose |
|-------|---------|
| `agent-ready` | Issue is properly scoped for agent execution |
| `agent-candidate` | Issue screener flagged as a candidate (human review needed) |
| `agent-generated` | PR was created by an AI agent |
| `needs-planning` | Requires agent planning phase before execution |
| `complexity:low` | Single file, clear pattern |
| `complexity:medium` | Multiple files, established patterns |
| `complexity:high` | Architectural decisions — triggers planning phase |

---

## Compound Engineering Integration

When `AGENT_PROVIDER=claude`, the trigger workflow uses **Compound Engineering** (a Claude Code plugin) for structured planning and execution:

- **`complexity:low` / `complexity:medium`**: Claude invokes `/ce-work` directly → opens a PR
- **`complexity:high`**: Claude invokes `/ce-plan` → commits a plan to `docs/plans/` → posts a comment asking for approval → a collaborator replies `/approve-plan` → Claude invokes `/ce-work` → opens a PR

This gives you human-in-the-loop oversight for architectural work while keeping simple tasks fully automated.

> Compound Engineering is a Claude Code plugin. Other providers use equivalent plain-language prompts without the CE skill layer.

---

## Documentation

- **[Agentic Development Guide](docs/AGENTIC_DEVELOPMENT.md)** — how to write agent-ready issues, workflow deep dive, provider setup, and CE integration details
- **[Implementation Plan](docs/plans/2026-06-12-001-feat-agentic-workflow-template-repo-plan.md)** — the plan used to build this template

---

## Customization

**Change required issue sections** — edit the `requiredSections` array in `.github/workflows/auto-label-agent-ready.yml`.

**Add CI checks** — create your own `.github/workflows/ci.yml` with stack-specific linting and tests. The template intentionally omits this (too stack-specific).

**Extend a stub provider** — find the `# TODO: extend for [provider]` comment in `agent-ready-trigger.yml` and add your invocation steps.

---

## Acknowledgements

This template was extracted and generalized from the agentic development workflow at Pew Research Center Engineering.
