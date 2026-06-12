---
title: "feat: GitHub Agentic Workflow Template Repository"
type: feat
status: completed
date: 2026-06-12
---

# feat: GitHub Agentic Workflow Template Repository

## Summary

Build a GitHub template repository that packages the agentic development workflow from Pew Research into a reusable, agent-agnostic scaffold. The template ships with issue/PR templates, label definitions, automated workflows, and an issue screener agent — all generalized to work with Claude Code (via Compound Engineering), OpenAI Codex, GitHub Copilot (via gh-aw), or any custom agent via a single `AGENT_PROVIDER` repository variable.

---

## Problem Frame

The Pew Research agentic workflow (agent-ready issue templates, auto-labeling, trigger workflows, issue screener) is tightly coupled to the PRC codebase: PHP/VIP conventions, PRC plugin paths, and the Anthropic `claude-code-action`. Other teams trying to adopt the same workflow have no starting point and must rebuild from scratch. The template closes that gap by extracting the durable, provider-agnostic core and adding a clean provider-routing layer.

---

## Requirements

- R1. All files from the PRC diff are represented in generalized form (no PRC-specific paths, stack references, or linter names)
- R2. A single `AGENT_PROVIDER` repository variable routes trigger workflows to the correct AI agent; v1 ships Claude fully supported — Codex, Copilot, and custom paths are functional stubs with clear extension points
- R3. Claude Code path integrates Compound Engineering: complexity `high` issues invoke `ce-plan` first with a human-gated approval step before `ce-work` runs; all other complexity levels invoke `ce-work` directly
- R4. Template includes an issue screener agent (generalized rubric, no PRC-specific scoring)
- R5. The repository is configured as a GitHub template (`is_template: true`)
- R6. Documentation covers setup, provider configuration, label sync, and CE integration
- R7. gh-aw (GitHub Agentic Workflows CLI) is offered as an optional alternative for teams that prefer it

---

## Scope Boundaries

- Stack-specific linting/testing commands are left as configurable placeholders — the template does not prescribe a language or framework
- Copilot Workspace (browser UI) and Cursor are documented but not automated with dedicated workflow files — they remain manual-start agents
- The issue screener is a triggered workflow file, not a gh-aw markdown workflow (keeps setup simpler for non-gh-aw teams)
- No CI validation workflow is included (too stack-specific); the documentation points to it as a follow-on step

### Deferred to Follow-Up Work

- gh-aw markdown workflow variant: A second set of `.github/workflows/*.md` files that can be compiled via `gh aw compile` — useful for PRC and other teams already on gh-aw
- Issue tracker integration in the screener (Asana, Linear, Jira): removed from v1 scope entirely — too provider-specific to generalize; teams can add their own enrichment step to the screener workflow

---

## Context & Research

### Reference Implementation

- `prc-platform/.github/ISSUE_TEMPLATE/agent-ready.md` — issue template (source)
- `prc-platform/.github/PULL_REQUEST_TEMPLATE/agent-generated.md` — PR template (source)
- `prc-platform/.github/LABELS.yml` — label definitions (source)
- `prc-platform/.github/workflows/agent-ready-trigger.yml` — Claude-specific trigger (source)
- `prc-platform/.github/workflows/auto-label-agent-ready.yml` — auto-label logic (source)
- `prc-platform/.github/agents/issue-screener.agent.md` — issue screener agent (source)
- `prc-platform/docs/AGENTIC_DEVELOPMENT.md` — developer guide (source)

### External References

- `anthropics/claude-code-action@v1` — Claude Code GitHub Action
- `openai/codex` — OpenAI Codex CLI (for `openai-codex` provider path)
- gh-aw (`github/gh-aw`) — GitHub Agentic Workflows CLI; supports Copilot, Claude, Codex engines
- `actions/github-script@v7` — used for auto-label and screener label logic

### Key Pattern: Provider Routing

The trigger workflow uses a GitHub Actions repository variable (`AGENT_PROVIDER`) to select execution path. This avoids requiring users to maintain multiple workflow files.

```
AGENT_PROVIDER=claude    → anthropics/claude-code-action (default, includes CE integration)
AGENT_PROVIDER=openai-codex → codex CLI via bash step
AGENT_PROVIDER=copilot   → gh-aw compiled workflow invocation
AGENT_PROVIDER=custom    → posts a webhook/dispatch event for bring-your-own agent
```

### CE Integration Pattern

When `AGENT_PROVIDER=claude`, the prompt passed to `claude-code-action` is complexity-aware:
- `complexity:high` → prompt invokes `/ce-plan` first, then awaits human approval comment before executing
- `complexity:medium` or `complexity:low` → prompt invokes `/ce-work` directly with the issue as input

The complexity label is read from `github.event.issue.labels` at workflow runtime.

---

## Key Technical Decisions

- **Single trigger workflow file** (not one per provider): Conditional `if:` steps in a single YAML file. Simpler to maintain, easier to reason about in the UI. The tradeoff is that non-matching steps still appear in the log as skipped — acceptable.
- **Repository variable, not secret, for `AGENT_PROVIDER`**: The provider choice is not sensitive. Using a variable (not a secret) makes it visible in the repo settings UI.
- **CE integration via prompt injection, not a custom Action**: The `ce-plan`/`ce-work` invocation lives in the prompt string, not in a separate composite action. This keeps the template dependency-free beyond the provider actions themselves.
- **Issue screener as a standalone workflow** (not a gh-aw agent file): Reduces setup friction for teams not using gh-aw. gh-aw variant deferred.
- **Generic linting/testing placeholders** (e.g., `npm test`, `make lint`) rather than omitting those fields: Keeps the templates instructive without dictating a stack.

---

## Open Questions

### Resolved During Planning

- **Where does the template live?** In `/Users/whyisjake/Sites/agentic-development/` — this directory is the new project root.
- **How does CE integration work when the agent is not Claude?** CE is Claude-only. For other providers, the prompt is a plain natural-language equivalent without CE skill invocations.
- **Should the issue screener support gh-aw?** Deferred — baseline is a standard YAML workflow.

### Deferred to Implementation

- **Exact Codex CLI invocation**: The `openai-codex` path depends on the current `codex` CLI release and whether a GitHub Action wrapper exists. Implementer should check at execution time.
- **Copilot provider path**: gh-aw integration requires `gh aw compile` at deploy time; the exact step shape depends on gh-aw version pinning.

---

## Output Structure

```
agentic-development/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   └── agent-ready.md
│   ├── PULL_REQUEST_TEMPLATE/
│   │   └── agent-generated.md
│   ├── LABELS.yml
│   ├── agents/
│   │   └── issue-screener.agent.md
│   ├── agents/
│   │   └── issue-screener.agent.md    ← opt-in Claude-powered screener
│   └── workflows/
│       ├── agent-ready-trigger.yml
│       ├── plan-approval-gate.yml     ← new: /approve-plan comment listener
│       ├── setup-labels.yml           ← new: one-time label sync
│       ├── auto-label-agent-ready.yml
│       └── issue-screener.yml         ← default github-script structural screener
├── docs/
│   ├── plans/                         (this plan)
│   └── AGENTIC_DEVELOPMENT.md
└── README.md
```

---

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```
┌──────────────────────────────────────────────────────────┐
│  Issue opened / edited                                   │
└────────────────────┬─────────────────────────────────────┘
                     │
          auto-label-agent-ready.yml
          (checks required sections)
                     │
              Has all sections?
              ────────┬────────
             Yes      │       No
              │       │       └── skip
              ▼
      apply `agent-ready` label
                     │
          agent-ready-trigger.yml
          (fires on label event)
                     │
         Read AGENT_PROVIDER variable
              ────────┬────────
   claude    codex   copilot  custom
      │        │        │       │
   ce-plan/  codex    gh-aw  dispatch
   ce-work    CLI    invoke   event
      │
  complexity routing:
  high → ce-plan (plan review gate)
  med/low → ce-work (direct execution)
                     │
              Agent creates PR
              (agent-generated label)
                     │
              Human review + CI
```

---

## Implementation Units

### U1. Repository Scaffold and GitHub Template Configuration

**Goal:** Initialize the project as a GitHub template repository with the right directory structure, README, and top-level metadata.

**Requirements:** R5

**Dependencies:** None

**Files:**
- Create: `README.md`
- Create: `.github/` directory structure (via subsequent units)

**Approach:**
- README covers: what the template is, the 5-minute quickstart (fork/use template → set `AGENT_PROVIDER` → sync labels → done), and links to the detailed guide
- The GitHub template flag (`is_template: true`) is set in the repository settings UI, not in a file — document this step in the README
- README includes a provider comparison table: Claude / Claude+CE, OpenAI Codex, Copilot, Custom

**Patterns to follow:**
- Keep README concise — quickstart first, depth in `docs/AGENTIC_DEVELOPMENT.md`

**Test scenarios:**
- Test expectation: none — pure documentation/scaffolding unit

**Verification:**
- README renders correctly with no broken links
- Directory structure matches Output Structure

---

### U2. Issue and PR Templates

**Goal:** Generalize the agent-ready issue template and agent-generated PR template, removing all PRC/VIP/PHP-specific references.

**Requirements:** R1

**Dependencies:** U1

**Files:**
- Create: `.github/ISSUE_TEMPLATE/agent-ready.md`
- Create: `.github/PULL_REQUEST_TEMPLATE/agent-generated.md`
- Create: `.github/LABELS.yml`

**Approach:**

*Issue template changes from PRC version:*
- Replace "Passes linting and code standards (PHPCS, ESLint)" → "Passes linting and code standards (project-specific)"
- Replace `/plugins/plugin-name/path/to/modify.php` path examples with generic `src/path/to/file` placeholders
- Replace "See `/plugins/prc-platform-core/...`" with "See `src/...` for similar implementation"
- Replace PHPUnit reference with stack-agnostic "project test suite"
- Keep all structural sections unchanged

*PR template changes from PRC version:*
- Remove "Follows VIP coding standards" → "Follows project coding standards"
- Remove PHP-specific security checklist items (nonce, `wp_kses`, capability checks) — replace with generic: "Input validation present", "No exposed secrets", "Data properly sanitized/escaped"
- Keep the structural sections and all non-stack-specific checklist items

*Labels:*
- Strip all PRC-specific labels (firebase, etc.) — include only the 7 agent-workflow labels from the diff
- Add comments in LABELS.yml explaining each label's role in the workflow

**Test scenarios:**
- Test expectation: none — template files; validation is visual review

**Verification:**
- Both templates render correctly in GitHub's issue/PR creation UI
- No PHP, WordPress, VIP, or PRC references remain
- LABELS.yml lints without errors

---

### U3. Auto-Label Workflow

**Goal:** Port the auto-label workflow with no functional changes — it is already generic — just clean up comments and remove any PRC references.

**Requirements:** R1

**Dependencies:** U2

**Files:**
- Create: `.github/workflows/auto-label-agent-ready.yml`

**Approach:**
- The existing logic (required sections check + scope boundaries + acceptance criteria) is already generic — keep it
- Update workflow name and comments to be template-neutral
- Add a comment block at the top explaining how to extend the required sections list for team-specific templates
- The `agent-ready` label must exist (created by U2's LABELS.yml sync) for the label-add step to succeed — note this dependency

**Test scenarios:**
- Happy path: Issue with all 5 sections + scope boundaries + one checkbox → `agent-ready` label applied
- Edge case: Issue missing `## Technical Notes` → label not applied, no error
- Edge case: Issue already has `agent-ready` label → workflow runs but no duplicate label added (GitHub deduplicates)
- Edge case: User pastes template skeleton (all headings present, all fields still placeholder text) → sections check passes, label applied; note this is a known acceptable false positive — the downstream agent prompt reads the issue and comments if it lacks real content
- Edge case: Two rapid edits within seconds of each other → two workflow runs fire; both attempt to add `agent-ready`; GitHub deduplicates, no double-trigger (label event only fires once per label, not per workflow run)
- Error path: `agent-ready` label does not exist in repo → `github.rest.issues.addLabels` throws; workflow logs error and exits non-zero; this is resolved by U7 (setup-labels workflow)

**Verification:**
- Opening a test issue with a complete template body results in the `agent-ready` label being applied
- Incomplete issues are not labeled

---

### U4. Agent-Agnostic Trigger Workflow with CE Integration

**Goal:** Replace the PRC Claude-only trigger with a provider-routing workflow that supports Claude (with Compound Engineering), OpenAI Codex, GitHub Copilot (gh-aw), and a generic webhook path.

**Requirements:** R2, R3, R7

**Dependencies:** U2, U3, U7

**Files:**
- Create: `.github/workflows/agent-ready-trigger.yml`

**Approach:**

The workflow fires on `issues: labeled` when `github.event.label.name == 'agent-ready'`.

Four conditional jobs (or steps within one job), keyed on `vars.AGENT_PROVIDER`:

**Claude path (default):**
- Uses `anthropics/claude-code-action@v1` with `CLAUDE_CODE_OAUTH_TOKEN`
- Prompt is complexity-aware: read `github.event.issue.labels` to detect `complexity:high`
- `complexity:high` prompt: instructs Claude to invoke `/ce-plan` on the issue, commit the plan to `docs/plans/` on a branch, then post a comment on the issue with the plan link and the instruction "Reply `/approve-plan` to begin implementation." Claude must not open a PR or write application code until `/approve-plan` is received.
- `complexity:medium` / `complexity:low` (or complexity label absent) prompt: instructs Claude to invoke `/ce-work` with the issue as input, then open a PR
- Shared prompt preamble: read the issue fully, respect "Out of scope" boundaries, reference Technical Notes patterns, comment on the issue if blocked
- Permissions: `contents: write`, `pull-requests: write`, `issues: write`, `id-token: write`, `actions: read`

**OpenAI Codex path:**
- Bash step that installs and invokes the `codex` CLI
- Passes issue body as `--instructions` or piped input
- Placeholder comment noting implementer should verify current Codex CLI invocation syntax

**Copilot / gh-aw path:**
- Runs `gh aw compile` on a pre-existing workflow markdown file
- Placeholder: links to gh-aw docs for setup
- Requires `gh-aw` installed in the runner

**Custom path:**
- Dispatches a `repository_dispatch` event with event type `agent-ready` and issue payload
- Allows teams to bring their own agent listener

**Test scenarios:**
- Happy path (Claude, complexity:low): Label applied → workflow fires → `ce-work` invoked → PR created
- Happy path (Claude, complexity:high): Label applied → workflow fires → `/ce-plan` invoked → plan file committed to branch → approval comment posted on issue → `/approve-plan` comment triggers `plan-approval-gate.yml` → `ce-work` runs → PR created
- Happy path (Claude, complexity label absent): Defaults to `ce-work` direct path (no stall)
- Edge case: `AGENT_PROVIDER` not set → defaults to Claude path (empty-string match)
- Edge case: `AGENT_PROVIDER=custom` → `repository_dispatch` event fires; workflow completes without error (note: listener workflow must exist in same repo to receive the event — document this)
- Error path: `CLAUDE_CODE_OAUTH_TOKEN` not set → action fails; Claude step should be wrapped so a comment is posted to the issue: "Agent setup incomplete — `CLAUDE_CODE_OAUTH_TOKEN` is required"
- Error path (CE failure): Claude runs but no plan file is committed (CE unavailable or failed silently) → post-Claude step checks for new file in `docs/plans/`; if absent, posts a comment and exits non-zero rather than posting a misleading approval-request comment
- Error path: `docs/plans/` branch commit blocked by branch protection → Claude step fails; workflow posts issue comment with the error text

**Verification:**
- Workflow file passes `actionlint` without errors
- Each conditional branch has a `name:` that clearly identifies the provider
- CE skill invocations (`/ce-plan`, `/ce-work`) appear in the Claude prompt strings

---

### U5. Issue Screener Agent

**Goal:** Generalize the PRC issue screener agent into a provider-agnostic, stack-agnostic version that any repository can use.

**Requirements:** R1, R4

**Dependencies:** U2

**Files:**
- Create: `.github/workflows/issue-screener.yml` (GitHub Actions workflow that invokes the screener)
- Create: `.github/agents/issue-screener.agent.md` (screener agent definition, mirroring PRC structure)

**Approach:**

*Scoring rubric changes:*
- Remove PRC-specific positive signals: "References a specific plugin, block, or file by name" with `prc-*` as the detection pattern → generalize to "References a specific file, class, module, or API by name"
- Remove PRC repo hardcoding (`pewresearch/prc-platform`) → use `context.repo.owner/context.repo.repo`
- Remove Asana Step 3 entirely (not deferred, just removed — it's too PRC-specific even as a stub)
- Keep the 6 positive signals and 3 negative signals, reworded to be generic
- Keep the `agent-candidate` (never `agent-ready`) discipline

*Workflow file:*
- Triggered on schedule (weekly) and on `workflow_dispatch`
- Uses `anthropics/claude-code-action@v1` (the screener is Claude-specific; document this in the workflow header)
- OR use `actions/github-script@v7` with a simpler JS implementation that just runs the scoring logic without LLM — offer this as the lightweight alternative

Decision: ship both. The `.agent.md` file is for the Claude-powered version. The `issue-screener.yml` includes a note pointing to it, but the default workflow implementation uses `github-script` for the structural check (no LLM cost), with the `.agent.md` as an opt-in for teams with Claude available.

**Test scenarios:**
- Happy path: Issue with score ≥ 7 → screener comment posted + `agent-candidate` label applied
- Happy path: Issue with score 5-6 → screener comment posted (lower confidence), `agent-candidate` applied
- Edge case: Issue with score < 5 → no comment, no label, logged as skipped
- Edge case: Issue already labeled `agent-candidate` → script skips (idempotency)
- Edge case: Issue already labeled `agent-ready` → script skips
- Error path: `agent-candidate` label does not exist → log error, continue to next issue (graceful degradation)
- Integration: After screener run, a human applies `agent-ready` → trigger workflow fires (U4 integration)

**Verification:**
- Screener runs on `workflow_dispatch` in a test repo and produces expected output
- `agent-ready` label is never applied by the screener
- Run summary is printed to workflow log

---

### U6. Documentation

**Goal:** Produce a generalized `AGENTIC_DEVELOPMENT.md` and a `SETUP.md` that replace the PRC-specific guide.

**Requirements:** R1, R6

**Dependencies:** U1 through U5

**Files:**
- Create: `docs/AGENTIC_DEVELOPMENT.md`
- Modify: `README.md` (add links to docs)

**Approach:**

`docs/AGENTIC_DEVELOPMENT.md` — port from PRC version with:
- Remove all "Pew Research Center" references → use "your team" / "your codebase"
- Replace PHP/WordPress/VIP-specific checklist items with generic equivalents
- Update the GitHub Integration section to cover the provider routing setup (new content)
- Add a "Compound Engineering Integration" section explaining the CE skill flow for Claude users
- Keep the workflow diagram (already generic)
- Add a provider comparison table at the top

`README.md` — new content covering:
- What this template is (one paragraph)
- Quickstart (numbered steps: use template → set secrets/variables → sync labels → open an issue)
- Provider setup table: `AGENT_PROVIDER` values + required secret + link to docs
- Links to `docs/AGENTIC_DEVELOPMENT.md`

**Test scenarios:**
- Test expectation: none — documentation unit

**Verification:**
- No PHP, WordPress, VIP, PHPCS, PRC, or Pew Research references remain in any file
- All internal links resolve
- Provider setup table is accurate against U4's workflow implementation

---

### U7. Plan-Approval Gate Workflow

**Goal:** Implement the `issue_comment`-triggered workflow that receives `/approve-plan` and resumes the `ce-work` execution step for high-complexity issues.

**Requirements:** R3

**Dependencies:** U4

**Files:**
- Create: `.github/workflows/plan-approval-gate.yml`

**Approach:**
- Trigger: `issue_comment: created` where comment body starts with `/approve-plan`
- Security: verify commenter has `write` or `admin` permission on the repository (`github.rest.repos.getCollaboratorPermissionLevel`); if not, post a reply comment "Only collaborators with write access can approve plans" and exit without error
- Idempotency: check whether a PR for this issue already exists (`gh pr list --search "Closes #N"`) — if yes, post "Implementation already in progress" and exit
- Retrieve the issue number from `github.event.issue.number`
- Invoke `anthropics/claude-code-action@v1` with a prompt instructing Claude to invoke `/ce-work` on the issue, using the committed plan in `docs/plans/` as context
- Post a comment on the issue linking to the Claude run when it completes

**Test scenarios:**
- Happy path: Collaborator posts `/approve-plan` → permission check passes → `ce-work` invoked → PR created
- Security: Non-collaborator posts `/approve-plan` → permission check fails → reply comment posted → no agent run
- Edge case: `/approve-plan` posted before plan is committed (e.g., manual comment on wrong issue) → no matching plan file in `docs/plans/` → Claude prompt includes instruction to check for plan and comment on the issue if absent
- Edge case: Duplicate `/approve-plan` comments → second run detects existing PR and exits with "already in progress" comment
- Edge case: `/approve-plan` on an issue without `complexity:high` label → workflow fires but `ce-work` runs against a plan that may not exist; Claude should note this and fall back to direct implementation

**Verification:**
- A collaborator posting `/approve-plan` on a complexity:high issue results in a new PR
- A non-collaborator's comment produces a reply but no agent run

---

### U8. Label Sync Setup Workflow

**Goal:** Provide a one-click (or one-command) setup step that imports all labels from `LABELS.yml` into the repository, resolving the bootstrap dependency that blocks U3 and U4.

**Requirements:** R6

**Dependencies:** U2

**Files:**
- Create: `.github/workflows/setup-labels.yml`

**Approach:**
- Trigger: `workflow_dispatch` only (never auto-run)
- Single step: `gh label import .github/LABELS.yml` using the built-in `GITHUB_TOKEN`
- If `gh label import` is not available in the runner's `gh` version, fall back to a `github-script` step that iterates LABELS.yml and calls `github.rest.issues.createLabel` / `github.rest.issues.updateLabel`
- Output: echo each label name and status (created / updated / skipped)
- Add this as step 2 in the README quickstart

**Test scenarios:**
- Happy path: All 7 agent-workflow labels are created from scratch → log shows "created" for each
- Happy path: Labels already exist → log shows "updated" (color/description refreshed) or "skipped" — no error
- Error path: `GITHUB_TOKEN` lacks `issues: write` scope → step fails with 403; log message explains required permission

**Verification:**
- After running `workflow_dispatch`, all 7 labels from `LABELS.yml` exist in the repository
- Workflow is idempotent — running it twice produces no errors

---

## System-Wide Impact

- **Interaction graph:** The three workflows interact in sequence: `auto-label` → `agent-ready-trigger` → (agent creates PR). The screener is independent and runs on a schedule.
- **Error propagation:** Each workflow should catch errors at the issue level and post a comment rather than silently failing — the issue is the human-visible surface.
- **State lifecycle risks:** The `agent-ready` label is the trigger. If auto-label fires and immediately triggers the execution workflow before a human intends it, that's undesirable. Mitigation: auto-label only fires when structural sections are present, not when all "Agent Readiness" checkboxes are checked — the checklist remains a human gate.
- **API surface parity:** The `agent-ready` label name is referenced in 3 places (LABELS.yml, auto-label workflow, trigger workflow) — must be consistent.
- **Unchanged invariants:** The template does not impose any CI pipeline. Teams bring their own branch protection and required checks.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| CE fails silently (exits zero, no plan committed) | Post-trigger step verifies `docs/plans/` has a new file; posts issue comment and exits non-zero if absent (U4, U7) |
| Plan-approval gate never fires (human never posts `/approve-plan`) | Document clearly; note this is intentional — issues stall at the planning stage until a human decides |
| Permission bypass on plan-approval gate | `getCollaboratorPermissionLevel` check in U7 gate; non-collaborators receive reply comment only |
| `agent-ready` label missing when trigger fires | U8 label sync setup workflow; U3 error path handles gracefully with a logged error |
| Codex and Copilot paths are stubs in v1 | R2 explicitly scopes v1 to "Claude fully supported"; stub paths have clear comments with extension instructions |
| Claude Code Action API changes | Pin `claude-code-action@v1`; README notes to check for updates |
| `AGENT_PROVIDER=custom` expects cross-repo webhook | Document: `repository_dispatch` requires a listener workflow in the same repo; for outbound HTTP, teams must add a `curl` step |
| `is_template` flag requires manual GitHub UI step | Explicit step 1 in README quickstart |
| Issue screener LLM path requires Claude setup | Default to `github-script` structural screener; `.agent.md` Claude path is opt-in |

---

## Sources & References

- Reference implementation: `prc-platform/.github/` (via diff)
- `prc-platform/.github/agents/agentic-workflows.agent.md` (gh-aw integration pattern)
- `prc-platform/.github/agents/issue-screener.agent.md` (screener agent source)
- Claude Code Action: `anthropics/claude-code-action@v1`
- gh-aw docs: `github/gh-aw` repository
- OpenAI Codex CLI: `github.com/openai/codex`
