# Agentic Development Guide

## Writing Issues That Agents Can Execute

**Version:** 1.0
**Date:** June 2026
**Audience:** Engineering teams adopting AI-assisted development

---

## The Core Idea

AI coding agents can take well-scoped issues 80–90% to completion before human review. The key word is **well-scoped**. A vague issue produces vague code. A precise issue produces precise code.

This guide teaches you how to write issues that agents can actually execute, how to configure the workflow for your chosen provider, and how to integrate Compound Engineering when using Claude.

---

## Provider Overview

| Provider | AGENT_PROVIDER value | Required secret | Notes |
|----------|---------------------|-----------------|-------|
| Claude + Compound Engineering | `claude` (default) | `CLAUDE_CODE_OAUTH_TOKEN` | Full support — complexity-aware, planning phase for high complexity |
| OpenAI Codex | `openai-codex` | `OPENAI_API_KEY` | Stub — configure the `trigger-openai-codex` job |
| GitHub Copilot (gh-aw) | `copilot` | _(gh-aw setup)_ | Stub — configure the `trigger-copilot` job |
| Custom / bring-your-own | `custom` | _(your own)_ | Dispatches `repository_dispatch` event; add your listener |

Set `AGENT_PROVIDER` in **Settings → Secrets and variables → Variables**. If not set, the workflow defaults to `claude`.

---

## What the Agent Can and Cannot Do in CI

Five constraints decide whether a run produces a pull request or nothing at all. The first is not optional, and the second is a security boundary.

**The permission mode is passed through `claude_args`, not `settings`.** `claude-code-action` runs interactively by default: in CI every `Write` waits on an approval nobody can give, and the run either produces nothing or burns to its timeout. Setting `permissions.defaultMode` inside the `settings` input looks like the fix and is not — a run configured that way reports `"permissionMode": "default"` and still refuses every write. The workflows here pass `claude_args: --permission-mode acceptEdits`, which does reach the SDK.

**The allow list is a trust boundary, and you will need to widen it.** `allow` grants Bash patterns; anything outside it is refused. The shipped list covers git, gh and read-only file utilities, and it deliberately does not know how your project runs its tests. Add that — `Bash(npm test)`, `Bash(php *)`, `Bash(pytest *)`, whatever applies — or the agent cannot verify its own work before opening a PR, while the issue template's "Tests pass" criterion asks it to. Observed cost of getting this wrong: roughly six minutes of a fifteen-minute budget spent re-attempting commands that could never be allowed.

Widen it deliberately, because of who is on the other end. **The issue body is untrusted input that reaches the model as instructions**, and the run carries `contents: write`, `pull-requests: write` and `issues: write` with writes pre-approved by `acceptEdits`. Anyone who can open an issue in your repository can therefore reach every command in this list. Two categories are worth refusing outright:

- **Anything that runs an arbitrary program.** `Bash(find *)` executes anything through `-exec`; `Bash(xargs *)` does the same through `sh -c`. Either one makes the rest of the list decorative.
- **Anything that reaches the network.** `Bash(curl *)` is outbound egress to any host, which is the step that turns "read the checkout" into "send the checkout somewhere".

Prefer the narrowest pattern that does the job: `Bash(npm test)` over `Bash(npm *)`, `Bash(composer install)` over `Bash(composer *)`. A wildcard is a subcommand you have not thought about yet.

**A refusal does not look like a policy decision to the agent.** This is the cost of the boundary above, and it is worth paying. Blocked commands come back as errors, and a model reasonably concludes the environment lacks the capability. In one run a blocked `curl` led the agent to state, in its PR body and in a committed fixture, that the environment had no network access — it had network; the command was not allowed. Anything you do not allow, expect to see described as impossible.

**An agent cannot modify `.github/workflows/`.** The GitHub App token has no `workflows` permission, so a push touching a workflow file fails with `refusing to allow a GitHub App to create or update workflow ... without 'workflows' permission`. An agent that writes tests therefore cannot wire them into CI; it has to hand you the YAML and you paste it. Worth saying in the issue when the task involves CI.

**Timeouts.** Jobs are capped at 30 minutes. A real feature on a small repo — three classes, two test files, iterating until the tests passed — took 20 minutes, so 15 was not enough. Raise it if your project's suite is slow; a stuck run with no cap consumes GitHub's 6-hour job limit.

---

## The 5 Elements of an Agent-Ready Issue

### 1. Clear Summary (One Sentence)

State what needs to happen in a single sentence. If you can't, the scope is too big.

**❌ Bad:**
> Improve the data pipeline

**✅ Good:**
> Add a REST endpoint that returns the latest pipeline run status as JSON

---

### 2. Context (Why This Matters)

Agents don't have institutional knowledge. Tell them:

- Why this feature exists
- Who uses it
- What problem it solves
- How it fits into the bigger picture

**Example:**
> External monitoring tools need programmatic access to pipeline status. Currently the status is only visible in the admin dashboard. A REST endpoint enables integration with Datadog, PagerDuty, and custom alerting scripts.

---

### 3. Acceptance Criteria (Checkboxes)

Define "done" with measurable criteria. Each criterion should be testable.

**❌ Vague:**
- [ ] API works correctly
- [ ] Good error handling

**✅ Specific:**
- [ ] `GET /api/v1/pipeline/status` returns `{ status, last_run_at, duration_ms }`
- [ ] Returns 404 when pipeline has never run
- [ ] Returns 503 when pipeline is currently failing
- [ ] Response includes `Cache-Control: no-cache` header
- [ ] Unit tests cover success, 404, and 503 cases

---

### 4. Scope Boundaries (In/Out)

Explicitly state what's included and excluded. Agents try to be helpful — sometimes too helpful. Boundaries prevent scope creep.

**Example:**
```
In scope:
- GET endpoint for current status
- JSON response format
- Error handling for missing/failed pipeline
- Unit tests

Out of scope:
- Authentication (existing endpoints are public)
- Historical run data (separate issue)
- Webhook notifications for status changes
```

---

### 5. Technical Notes (The Cheat Sheet)

Give the agent everything it needs to match your codebase:

- **Key files** to read or modify
- **Patterns to follow** (link to similar implementations)
- **Dependencies** and configuration
- **Testing approach**

**Example:**
```
Key files:
- src/api/routes/pipeline.ts (create here)
- src/api/routes/health.ts (pattern reference)

Patterns to follow:
- Route registration in src/api/index.ts
- Error response format matches src/api/errors.ts

Testing:
- Jest tests in src/api/__tests__/
- Follow health.test.ts structure
```

---

## The Agent-Ready Checklist

Before labeling an issue `agent-ready`:

- [ ] **Scope is bounded** — Can be completed in one PR
- [ ] **Success is measurable** — Clear pass/fail criteria
- [ ] **Context is sufficient** — Agent can understand why without asking
- [ ] **Patterns are referenced** — Links to similar code in the repo
- [ ] **No external blockers** — API keys available, dependencies installed
- [ ] **Complexity is labeled** — `complexity:low`, `complexity:medium`, or `complexity:high`

---

## Complexity Levels

### `complexity:low`
- Single file changes
- Following an obvious existing pattern
- Bug fixes with clear reproduction steps
- Adding tests for existing code

**Example:** Add validation for empty input in an existing form handler

### `complexity:medium`
- Multiple related files
- New feature following established patterns
- Refactoring with clear before/after states
- Integration with one external system

**Example:** Add REST endpoints following existing API patterns in the codebase

### `complexity:high`
- Architectural decisions required
- Multiple system integrations
- New patterns being established
- Performance-critical code paths

**Example:** Design and implement a multi-provider data pipeline with fallback logic

> **Note:** `complexity:high` issues trigger a planning phase when using Claude + CE. The agent generates an implementation plan that a human approves before any code is written.

---

## The Workflow

```
┌─────────────────────────────────────────────────────────────┐
│  1. DEFINE (Human)                                          │
│     Write agent-ready issue with all 5 elements             │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  2. PLAN (Agent + Human)  — complexity:high only            │
│     Agent proposes implementation plan                      │
│     Human reviews: reply /approve-plan to proceed           │
│     (Skipped for low/medium complexity)                     │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  3. EXECUTE (Agent)                                         │
│     Agent implements against issue (and plan if present)    │
│     Creates PR with summary and testing notes               │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  4. VALIDATE (Human + CI)                                   │
│     CI runs automated checks                                │
│     Human reviews for correctness, security, patterns       │
│     Request changes or approve                              │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  5. FINALIZE (Human)                                        │
│     Merge PR                                                │
│     Deploy via your standard process                        │
│     Close issue                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Compound Engineering Integration

[Compound Engineering](https://github.com/anthropics/compound-engineering) is a Claude Code plugin that provides structured planning (`/ce-plan`) and work execution (`/ce-work`) skills.

> **Important:** CE plugin slash commands (`/ce-plan`, `/ce-work`) only work in a local, interactive Claude Code session where the plugin is installed. **They are not available in GitHub Actions CI.** The `agent-ready-trigger.yml` workflow uses direct prompts instead — Claude reads the issue, implements the fix, and opens a PR without the plugin. CE is an optional local enhancement, not a CI dependency.

### CI Workflow: Low/Medium Complexity

```
agent-ready label applied
        ↓
agent-ready-trigger.yml fires
        ↓
Claude reads issue via gh CLI, reads CLAUDE.md and key files
        ↓
Claude implements the feature, commits, and opens a PR
```

### CI Workflow: High Complexity

```
agent-ready label applied
        ↓
agent-ready-trigger.yml fires
        ↓
Claude reads issue, writes a plan to docs/plans/
        ↓
Plan committed on a branch
        ↓
Claude posts comment: "Review plan → reply /approve-plan to implement"
        ↓
Human reviews the plan (in docs/plans/)
        ↓
Human replies /approve-plan
        ↓
plan-approval-gate.yml fires
        ↓
Claude reads the plan file and implements it, opens a PR
```

### Using CE Interactively (Local Sessions Only)

If you have Compound Engineering installed locally, you can use it to plan and execute from your terminal — the output feeds into the same `docs/plans/` format the CI workflow reads:

```bash
# Plan a feature from an issue (local only)
claude "/ce-plan [paste issue description or use issue URL]"

# Execute a plan (local only)
claude "/ce-work docs/plans/2026-01-15-001-feat-my-feature-plan.md"

# Or work from the issue directly (local only)
claude "/ce-work Implement the feature described in GitHub issue #42"
```

CE is an optional enhancement for local sessions. The CI workflow works without it.

---

## GitHub Setup

### Initial Setup (One Time)

1. **Use the template** — Click "Use this template" on GitHub
2. **Enable the template flag** — Settings → General → check "Template repository"
3. **Sync labels** — Actions → Setup Labels → Run workflow
4. **Set your provider** — Settings → Secrets and variables → Variables → `AGENT_PROVIDER`
5. **Add your secret** — Settings → Secrets and variables → Secrets → add the required token

### Labels

The workflow uses 7 labels. All are created by the Setup Labels workflow.

| Label | Applied by | Meaning |
|-------|-----------|---------|
| `agent-ready` | Human or auto-labeler | Issue is scoped for agent execution |
| `agent-candidate` | Issue screener | Screener flagged as promising — human review needed |
| `agent-generated` | Agent | PR was created by an agent |
| `needs-planning` | Human | Manual flag: this issue needs a plan before execution |
| `complexity:low` | Human | Single file, clear pattern |
| `complexity:medium` | Human | Multiple files, established patterns |
| `complexity:high` | Human | Architectural work — triggers planning phase |

### Adding CI Checks

This template intentionally omits a CI workflow — linting and testing commands are too stack-specific to generalize. Add your own:

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install
        run: npm install  # or: pip install, bundle install, etc.
      - name: Lint
        run: npm run lint
      - name: Test
        run: npm test
```

### Code Review Guidelines for Agent PRs

When reviewing agent-generated code, focus on:

**1. Intent Match**
- Does the code actually solve the issue?
- Are acceptance criteria met?

**2. Pattern Adherence**
- Does it follow existing codebase patterns?
- Are naming conventions consistent?

**3. Edge Cases**
- What happens with empty inputs?
- Error handling present and correct?
- Boundary conditions covered?

**4. Security**
- Input validation present?
- No exposed secrets?
- Data properly sanitized?

**5. Tests**
- Are tests actually testing behavior?
- Edge cases covered?
- Not just the happy path?

---

## When Agents Excel

✅ **Use agents for:**
- Implementing features against clear specs
- Following established patterns to new areas
- Writing tests for existing code
- Refactoring with defined outcomes
- Bug fixes with clear reproduction steps
- Documentation generation
- Boilerplate and scaffolding

---

## When Agents Struggle

⚠️ **Be cautious with:**
- Vague requirements ("make it better")
- Novel architecture decisions
- Performance optimization without metrics
- Security-critical code (always human review)
- Code requiring deep institutional knowledge

> For these cases, use agents in **interactive mode** — work alongside them rather than delegating fully.

---

## Anti-Patterns to Avoid

### The Kitchen Sink Issue
**Problem:** Issue tries to do too much
**Fix:** Split into focused issues, link them with dependencies

### The Assumption Issue
**Problem:** Assumes agent knows your conventions
**Fix:** Link to specific examples, name the patterns explicitly

### The Moving Target
**Problem:** Requirements change during execution
**Fix:** New requirements = new issue. Keep original scope.

### The Mystery Context
**Problem:** No explanation of why
**Fix:** Always include context explaining purpose and users

### The Perfectionist Trap
**Problem:** Expecting production-perfect output
**Fix:** Expect 80–90%. Plan for human review and refinement.

---

## Extending Provider Stubs

The `openai-codex` and `copilot` jobs in `agent-ready-trigger.yml` are intentional stubs. To activate them:

1. Open `.github/workflows/agent-ready-trigger.yml`
2. Find the stub job for your provider (search for `# TODO: extend`)
3. Replace the stub `run:` block with your actual invocation
4. Add the required secret (see the job's `env:` block)

If you build a working provider integration, consider contributing it back via a PR!

---

## Quick Reference

| Element | Question It Answers |
|---------|---------------------|
| Summary | What are we building? |
| Context | Why does it matter? |
| Acceptance Criteria | How do we know it's done? |
| Scope Boundaries | What's in and out? |
| Technical Notes | How do we build it? |

---

## Getting Started

1. **Start small** — Pick a `complexity:low` issue for your first agent-assisted task
2. **Use the template** — It forces good structure
3. **Review agent output** — Learn what works and what needs refinement
4. **Iterate on issues** — Improve your issue-writing based on results
5. **Share learnings** — Document patterns that work for your codebase

---

_This is a living document. Update it as you learn what works for your team._
