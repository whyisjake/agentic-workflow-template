# Agentic Workflow Template

A GitHub template repository that brings structured, agent-assisted development to any codebase. Drop it into your repository to get issue templates, automated labeling, and AI agent workflows that route to **Claude Code**, **OpenAI Codex**, **GitHub Copilot**, or a **custom agent** — all configured with a single repository variable.

Built on the workflow developed at [Pew Research Center](https://pewresearch.org) and generalized for any team.

---

## How It Works

1. A developer opens an issue using the **Agent-Ready template**
2. When the issue is complete (all required sections filled), it's auto-labeled `agent-ready`
3. The trigger workflow fires and routes to your configured AI agent
4. The agent implements the feature and opens a PR
5. A human reviews and merges

For `complexity:high` issues, Claude + Compound Engineering runs a planning phase first — generating a structured implementation plan that a human approves before any code is written.

---

## Quickstart (5 minutes)

**Step 1 — Use this template**

Click **Use this template** → **Create a new repository** on GitHub, then enable the template flag in Settings → General → "Template repository".

**Step 2 — Sync labels**

Run the label sync workflow once to create all agent workflow labels in your repo:

```
Actions → Setup Labels → Run workflow
```

**Step 3 — Configure your agent**

Set a repository variable (`Settings → Secrets and variables → Variables`):

| Variable | Value | Required secret |
|----------|-------|-----------------|
| `AGENT_PROVIDER` | `claude` (default) | `CLAUDE_CODE_OAUTH_TOKEN` |
| `AGENT_PROVIDER` | `openai-codex` | `OPENAI_API_KEY` |
| `AGENT_PROVIDER` | `copilot` | _(gh-aw setup required — see docs)_ |
| `AGENT_PROVIDER` | `custom` | _(your own listener — see docs)_ |

If `AGENT_PROVIDER` is not set, the workflow defaults to `claude`.

**Step 4 — Open an agent-ready issue**

Use the **Agent-Ready Task** issue template. Fill in all sections. When the issue is complete, add the `agent-ready` label (or let the auto-labeler apply it) to start the agent.

---

## Provider Details

| Provider | Status | Notes |
|----------|--------|-------|
| **Claude + Compound Engineering** | ✅ Full support | Complexity-aware: high issues plan first, low/medium execute directly |
| **OpenAI Codex** | 🔧 Stub — extend to fit your setup | See `.github/workflows/agent-ready-trigger.yml` |
| **GitHub Copilot (gh-aw)** | 🔧 Stub — extend to fit your setup | Requires `gh aw compile` setup |
| **Custom** | 🔧 `repository_dispatch` event | Wire your own agent listener in the same repo |

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
