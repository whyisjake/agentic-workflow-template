---
title: "fix: Add headless permissions and timeouts to CI agent workflows"
type: fix
status: active
date: 2026-06-17
---

# fix: Add headless permissions and timeouts to CI agent workflows

## Summary

Retrofits `agent-ready-trigger.yml` and `plan-approval-gate.yml` with the headless permission settings and job-level timeouts already established in the companion `claude-pr-feedback.yml` workflow (PR #4). Without these, claude steps default to interactive permission mode and hang indefinitely in CI, silently consuming up to GitHub's 6-hour job cap with no output and no PR produced.

---

## Problem Frame

Three compounding issues cause the `claude` provider to produce no PR and run for ~30 minutes (or longer) before the job is manually cancelled:

1. **Interactive permissions** — `claude-code-action` defaults to interactive mode; every `Write`/`Bash` call blocks waiting for human approval that never arrives in CI.
2. **No output** — without `show_full_output`, runs emit only the `init` event, making the hang undiagnosable from logs.
3. **No timeout** — without `timeout-minutes`, stuck runs consume GitHub's 6-hour job cap.

The fix pattern already exists in `claude-pr-feedback.yml` (PR #4); this plan applies it to the two older workflows.

---

## Requirements

- R1. Claude steps in `agent-ready-trigger.yml` must run non-interactively in CI (no hanging on permission approvals).
- R2. Claude steps in `plan-approval-gate.yml` must run non-interactively in CI.
- R3. Both workflows must have a hard timeout so stuck runs don't reach the 6-hour GitHub cap.
- R4. The `plan-approval-gate.yml` job must have `actions: read` permission (currently missing, required for `additional_permissions: actions: read` in the claude step to work).
- R5. The `show_full_output` debug option must be available (commented out) so operators can enable it without hunting for the right field name.

---

## Scope Boundaries

- Does not change the logic, prompts, or branching behavior of either workflow.
- Does not modify the `allow` list beyond `Bash(git *)` and `Bash(gh *)`.
- Does not enable `show_full_output` by default — leaving it as a commented debug option only.
- Does not add error-handler steps (tracked separately; see Deferred).
- Does not touch `auto-label-agent-ready.yml`, `issue-screener.yml`, or `setup-labels.yml`.

### Deferred to Follow-Up Work

- Failure handler steps (posting a comment when the run errors or times out): separate follow-up issue — this plan addressed the same pattern gap in the PR #4 review.

---

## Context & Research

### Relevant Code and Patterns

- `.github/workflows/claude-pr-feedback.yml` — source of the headless settings pattern; uses `defaultMode: acceptEdits`, `allow: [Bash(git *), Bash(gh *)]`, `timeout-minutes: 15` at job level, and `show_full_output` commented out.
- `.github/workflows/agent-ready-trigger.yml` — has two claude steps: Planning Phase (complexity:high) and Direct Execution (complexity:low/medium). Both need the headless block. Already has `actions: read` in job permissions.
- `.github/workflows/plan-approval-gate.yml` — has one claude step: Run Claude Code with /ce-work. Missing `actions: read` from job permissions block.

### External References

- `anthropics/claude-code-action` docs: `settings` field accepts a JSON string with a `permissions` object; `defaultMode: acceptEdits` enables non-interactive file editing; `allow` grants specific Bash patterns without full bypass.

---

## Key Technical Decisions

- **`acceptEdits` over `bypassPermissions`**: More conservative — the agent can edit files and run git/gh commands but all other Bash calls still require explicit allow-listing. Consistent with the pattern already established in PR #4.
- **Job-level `timeout-minutes: 15`**: Bounds the entire job (checkout + permission check + agent run), not just the claude step. Consistent with `claude-pr-feedback.yml`. Sufficient for typical agent runs; operators can increase if needed.
- **`show_full_output` commented out**: Avoids log verbosity in normal runs while making the flag discoverable for debugging.
- **`actions: read` added to `plan-approval-gate.yml`**: The job declares `additional_permissions: actions: read` in the claude step but the job-level permissions block didn't include it, which silently zeroed it out (same class of bug as the `contents: read` issue fixed in PR #5).

---

## Open Questions

### Resolved During Planning

- **`acceptEdits` vs `bypassPermissions`**: Resolved — use `acceptEdits`. (User confirmed; consistent with PR #4.)
- **Where to apply timeout**: Job level, not step level. Consistent with `claude-pr-feedback.yml`.

### Deferred to Implementation

- Whether 15 minutes is the right cap for the planning phase (complexity:high) which may run longer than direct execution: implementer should verify against observed run times and adjust if needed.

---

## Implementation Units

### U1. Fix `agent-ready-trigger.yml` — headless settings and timeout

**Goal:** Make both claude steps in the agent-ready trigger run non-interactively, with a hard timeout and a discoverable debug flag.

**Requirements:** R1, R3, R5

**Dependencies:** None

**Files:**
- Modify: `.github/workflows/agent-ready-trigger.yml`

**Approach:**
- Add `timeout-minutes: 15` to the `trigger-claude` job (same level as `runs-on`).
- Add a `settings` block to both `Run Claude Code — Planning Phase` and `Run Claude Code — Direct Execution` steps, matching the JSON structure in `claude-pr-feedback.yml`.
- Add `# show_full_output: true` as a commented line inside each `with:` block for discoverability.
- The two stub jobs (`trigger-openai-codex`, `trigger-copilot`, `trigger-custom`) are unaffected.

**Patterns to follow:**
- `.github/workflows/claude-pr-feedback.yml` — exact shape of the `settings:` and `timeout-minutes:` fields.

**Test scenarios:**
- Happy path: After the fix, label an issue `agent-ready` in a repo with `AGENT_PROVIDER=claude`; the job should complete (or fail on a real error) within 15 minutes rather than hanging.
- Happy path: A complexity:low issue triggers Direct Execution; the claude step proceeds without permission-approval prompts and either opens a PR or posts a clarification comment.
- Happy path: A complexity:high issue triggers Planning Phase; Claude runs `/ce-plan`, commits a plan file, and posts a comment — all without interactive approvals.
- Edge case: If the agent run genuinely exceeds 15 minutes, the job times out and GitHub marks it as failed (not hung indefinitely).
- Integration: The existing `Check for missing CLAUDE_CODE_OAUTH_TOKEN` failure handler still fires when the secret is absent.

**Verification:**
- Both claude steps have a `settings:` field with `defaultMode: acceptEdits` and `allow: [Bash(git *), Bash(gh *)]`.
- The `trigger-claude` job has `timeout-minutes: 15`.
- `show_full_output` is present as a comment in both steps.
- The workflow YAML is valid (passes `actionlint` or equivalent).

---

### U2. Fix `plan-approval-gate.yml` — headless settings, timeout, and missing permission

**Goal:** Make the plan-approval gate's claude step run non-interactively, add a hard timeout, and fix the missing `actions: read` job permission.

**Requirements:** R2, R3, R4, R5

**Dependencies:** None (can land in the same PR as U1 or separately)

**Files:**
- Modify: `.github/workflows/plan-approval-gate.yml`

**Approach:**
- Add `actions: read` to the `handle-approve-plan` job's `permissions` block (alongside the existing `contents`, `pull-requests`, `issues`, `id-token` entries).
- Add `timeout-minutes: 15` to the `handle-approve-plan` job.
- Add the same `settings:` block to the `Run Claude Code with /ce-work` step.
- Add `# show_full_output: true` as a commented line.
- The permission-check and idempotency-check steps are unaffected.

**Patterns to follow:**
- `.github/workflows/claude-pr-feedback.yml` — settings block shape.
- `.github/workflows/agent-ready-trigger.yml` — existing `actions: read` in the job permissions block as the reference for the correct structure.

**Test scenarios:**
- Happy path: A collaborator comments `/approve-plan` on an issue with a plan file; the claude step runs `/ce-work`, opens a PR, and exits within 15 minutes.
- Happy path: A non-collaborator commenting `/approve-plan` still receives the "no write access" reply; the claude step is never reached (permission check gates it).
- Edge case: An `/approve-plan` on an issue that already has an open PR hits the idempotency check and posts the existing-PR link; no agent run starts.
- Integration: The `additional_permissions: actions: read` in the claude step now resolves correctly because the job-level permissions block includes `actions: read`.

**Verification:**
- The `handle-approve-plan` job's `permissions` block includes `actions: read`.
- `timeout-minutes: 15` is present at the job level.
- The claude step has the `settings:` block with `defaultMode: acceptEdits` and the `allow` list.
- The workflow YAML is valid.

---

## System-Wide Impact

- **Interaction graph:** Both workflows are triggered by GitHub events (label add, issue comment). The headless settings change only how the `claude-code-action` step behaves internally — trigger conditions and downstream steps are unaffected.
- **Error propagation:** Adding a timeout means previously-infinite hangs now produce a hard failure at 15 minutes. Existing failure handlers (in `agent-ready-trigger.yml`) will fire on timeout. `plan-approval-gate.yml` has no failure handler yet (deferred).
- **Unchanged invariants:** Permission checks, idempotency logic, label routing, and all prompt content remain unchanged. The `openai-codex`, `copilot`, and `custom` stub jobs in `agent-ready-trigger.yml` are not touched.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| 15-minute timeout too short for complex planning runs | Can be increased per-job; start at 15 to match PR #4 and adjust based on observed run times |
| `acceptEdits` still blocks on non-git/gh Bash calls the prompt uses | Review the prompt content in both workflows; if any Bash calls outside git/gh are needed, extend the `allow` list accordingly |
| `actions: read` fix in `plan-approval-gate.yml` may silently already work due to GitHub defaults | Low risk — explicit is correct regardless; matches how `agent-ready-trigger.yml` is already written |

---

## Sources & References

- Related issue: #6
- Pattern source: `.github/workflows/claude-pr-feedback.yml` (PR #4)
- Related fix: PR #5 (`contents: read` missing from `setup-labels.yml` — same class of permissions omission)
