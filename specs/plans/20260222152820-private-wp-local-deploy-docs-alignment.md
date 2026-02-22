# Local Direct Deploy for Private WordPress

## TL;DR
> **Summary**: Replace the current GitHub-hosted WordPress fetch/deploy path with a local build + direct Cloudflare deploy workflow for private/local WordPress environments, then align docs to the new canonical flow.
> **Deliverables**:
> - Remove obsolete hosted fetch/deploy workflow
> - Add a single script-wrapper deploy interface for local production deploy
> - Update docs to reflect private WordPress reachability constraints and new deploy flow
> - Correct image documentation drift to current implementation
> **Effort**: Medium
> **Parallel**: YES - 2 waves
> **Critical Path**: Task 1 -> Task 3 -> Task 6 -> Task 8

## Context
### Original Request
User identified that GitHub-hosted Actions cannot fetch from WordPress when WordPress is local/private, asked to review deployment viability, and selected local build + direct deploy as the new default.

### Interview Summary
- Current hosted workflow fetches WP content in CI and deploys to Cloudflare Pages.
- User environment may host WordPress locally or on private VPS.
- User selected decisions:
  - Architecture: local build + direct deploy
  - Execution model: manual command
  - Scope: production deploy only (no previews)
  - Workflow action: old hosted workflow can be deleted and docs updated
  - Image docs: align to current implementation now

### Metis Review (gaps addressed)
- Added explicit decision to remove/replace ambiguous dual deploy paths.
- Added strict out-of-scope guardrails (no Cloudflare Images migration, no sync redesign).
- Added acceptance criteria to ensure docs and workflow are consistent with private WP reachability.

## Work Objectives
### Core Objective
Make private/local WordPress deployments reliable by moving to a canonical local production deploy flow and removing hosted CI assumptions that require CI-to-WP network access.

### Deliverables
- New canonical local deploy wrapper script path and usage docs.
- Updated deployment documentation with clear primary path and constraints.
- Removed obsolete `.github/workflows/deploy.yml` workflow that fetches from WP.
- Updated image optimization docs to match current implementation behavior.

### Definition of Done (verifiable conditions with commands)
- `test -x scripts/deploy-local.sh` exits 0.
- `grep -n "deploy-local.sh" README.md docs/*.md` returns references to canonical command.
- `test ! -f .github/workflows/deploy.yml` exits 0.
- `grep -n "WebP" docs/image-optimization.md` returns current format documentation.
- `grep -n "AVIF" docs/image-optimization.md` either returns 0 matches or only explicit future-scope notes.

### Must Have
- Single canonical production deploy command for local execution.
- Explicit docs stating hosted CI cannot fetch private/local WP unless additional networking is configured.
- Deploy artifact remains `hugo-site/public`.
- Image docs reflect current code behavior.

### Must NOT Have (guardrails, AI slop patterns, scope boundaries)
- Must NOT introduce Cloudflare Images migration work.
- Must NOT add preview deployment workflows.
- Must NOT redesign sync-server architecture.
- Must NOT add ambiguous dual-primary deploy paths.

## Verification Strategy
> ZERO HUMAN INTERVENTION — all verification is agent-executed.
- Test decision: tests-after + existing shell/Ruby checks (no new test framework setup)
- QA policy: Every task includes agent-executed happy + failure scenarios
- Evidence: `.sisyphus/evidence/task-{N}-{slug}.{ext}`

## Execution Strategy
### Parallel Execution Waves
> Target: 5-8 tasks per wave. <3 per wave (except final) = under-splitting.
> Extract shared dependencies as Wave-1 tasks for max parallelism.

Wave 1: workflow and deploy-interface foundation (workflow removal, script wrapper, dependency docs, command contracts)
Wave 2: docs alignment and consistency enforcement (README/docs updates, image docs correction, validation commands)

### Dependency Matrix (full, all tasks)
- Task 1 blocks Tasks 4, 5
- Task 2 blocks Tasks 3, 4, 8
- Task 3 blocks Tasks 6, 8
- Task 4 blocks Task 8
- Task 5 blocks Task 8
- Task 6 blocks Task 8
- Task 7 blocks Task 8

### Agent Dispatch Summary (wave -> task count -> categories)
- Wave 1 -> 4 tasks -> quick, unspecified-low
- Wave 2 -> 4 tasks -> writing, quick, unspecified-low

## TODOs
> Implementation + Test = ONE task. Never separate.
> EVERY task MUST have: Agent Profile + Parallelization + QA Scenarios.

- [x] 1. Remove obsolete hosted WordPress fetch/deploy workflow

  **What to do**: Delete `.github/workflows/deploy.yml`, then update all references that present it as active default behavior.
  **Must NOT do**: Do not remove unrelated workflows; do not change Cloudflare credentials guidance beyond what is needed for local deploy path.

  **Recommended Agent Profile**:
  - Category: `quick` — Reason: single-file deletion + targeted reference updates
  - Skills: `[]` — no special skill required
  - Omitted: `[git-master]` — commit work is not part of this task

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: [4, 5] | Blocked By: []

  **References** (executor has NO interview context — be exhaustive):
  - Pattern: `.github/workflows/deploy.yml` — workflow currently fetches WP and deploys from CI
  - Pattern: `README.md` — deployment section references workflow trigger commands

  **Acceptance Criteria** (agent-executable only):
  - [ ] `test ! -f .github/workflows/deploy.yml` exits 0
  - [ ] `grep -R "workflow run deploy.yml" README.md docs || true` shows no active-instructions usage

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```bash
  Scenario: Hosted workflow removed
    Tool: Bash
    Steps: run `test ! -f .github/workflows/deploy.yml`
    Expected: exit code 0
    Evidence: .sisyphus/evidence/task-1-remove-hosted-workflow.txt

  Scenario: Failure if file still exists
    Tool: Bash
    Steps: run `ls .github/workflows/deploy.yml`
    Expected: command fails with not found
    Evidence: .sisyphus/evidence/task-1-remove-hosted-workflow-error.txt
  ```

  **Commit**: YES | Message: `chore(ci): remove hosted wordpress fetch deploy workflow` | Files: [.github/workflows/deploy.yml, README.md, docs/*]

- [x] 2. Add canonical local production deploy wrapper script

  **What to do**: Create `scripts/deploy-local.sh` that performs deterministic sequence: validate env -> fetch posts/pages/images/comments (when token present) -> build Hugo -> deploy via `wrangler pages deploy hugo-site/public --project-name "$CLOUDFLARE_PAGES_PROJECT"`.
  **Must NOT do**: Do not hardcode secrets; do not add preview deployment logic.

  **Recommended Agent Profile**:
  - Category: `unspecified-low` — Reason: multi-step shell script with env validation
  - Skills: `[]` — existing shell patterns are sufficient
  - Omitted: `[playwright]` — no browser automation required

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: [3, 4, 8] | Blocked By: []

  **References** (executor has NO interview context — be exhaustive):
  - Pattern: `docs/workflow-reference.md` — local fetch/build command sequence
  - Pattern: `docs/local-dev-setup.md` — environment conventions for `WP_API_URL` and builder usage
  - Pattern: `scripts/fetch-posts.rb` — required fetch step
  - Pattern: `scripts/fetch-pages.rb` — required fetch step
  - Pattern: `scripts/fetch-images.rb` — required image step
  - Pattern: `scripts/fetch-comments.rb` — optional comments fetch step

  **Acceptance Criteria** (agent-executable only):
  - [ ] `test -x scripts/deploy-local.sh` exits 0
  - [ ] `bash -n scripts/deploy-local.sh` exits 0
  - [ ] `grep -n "CLOUDFLARE" scripts/deploy-local.sh` confirms env variable checks

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```bash
  Scenario: Script validates syntax and executable bit
    Tool: Bash
    Steps: run `bash -n scripts/deploy-local.sh && test -x scripts/deploy-local.sh`
    Expected: exit code 0
    Evidence: .sisyphus/evidence/task-2-local-wrapper.txt

  Scenario: Missing env fails fast
    Tool: Bash
    Steps: run script with `CLOUDFLARE_API_TOKEN` unset
    Expected: non-zero exit and explicit missing-var error message
    Evidence: .sisyphus/evidence/task-2-local-wrapper-error.txt
  ```

  **Commit**: YES | Message: `feat(deploy): add local production deploy wrapper` | Files: [scripts/deploy-local.sh]

- [x] 3. Define deploy dependency contract and install guidance

  **What to do**: Add concise dependency section documenting required local tools (`docker compose`, `hugo` if needed by chosen path, `wrangler`), required env vars, and preflight checks used by `scripts/deploy-local.sh`.
  **Must NOT do**: Do not document optional tool variants as co-equal primary paths.

  **Recommended Agent Profile**:
  - Category: `writing` — Reason: policy/usage documentation with strict command accuracy
  - Skills: `[]` — no external library deep dive needed
  - Omitted: `[frontend-ui-ux]` — not applicable

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: [6, 8] | Blocked By: [2]

  **References** (executor has NO interview context — be exhaustive):
  - Pattern: `README.md` — prerequisites and deploy sections
  - Pattern: `docs/local-dev-setup.md` — existing env-variable explanation style
  - API/Type: `scripts/deploy-local.sh` — authoritative contract for required vars
  - External: `https://developers.cloudflare.com/pages/platform/limits/` — platform limits context

  **Acceptance Criteria** (agent-executable only):
  - [ ] `grep -n "deploy-local.sh" README.md docs/*.md` returns at least one canonical usage location
  - [ ] `grep -n "CLOUDFLARE_API_TOKEN\|CLOUDFLARE_ACCOUNT_ID\|CLOUDFLARE_PAGES_PROJECT" README.md docs/*.md` returns documented requirements

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```bash
  Scenario: Dependency contract discoverable
    Tool: Bash
    Steps: run grep commands for deploy script and required env vars
    Expected: matches found in designated docs files
    Evidence: .sisyphus/evidence/task-3-dependency-contract.txt

  Scenario: Missing dependency docs caught
    Tool: Bash
    Steps: run grep for each required var and fail if count is 0
    Expected: script exits non-zero when any var doc is absent
    Evidence: .sisyphus/evidence/task-3-dependency-contract-error.txt
  ```

  **Commit**: YES | Message: `docs(deploy): document local deploy dependencies and env contract` | Files: [README.md, docs/*]

- [x] 4. Rewrite deployment docs to private-WordPress-safe primary flow

  **What to do**: Update README and deployment-related docs so the primary path is local production deploy; explicitly state hosted CI fetch is incompatible by default with private/local WP.
  **Must NOT do**: Do not leave dual-primary wording; do not claim hosted CI can reach `http://wordpress`.

  **Recommended Agent Profile**:
  - Category: `writing` — Reason: cross-doc consistency and policy wording
  - Skills: `[]` — repository docs are sufficient
  - Omitted: `[oracle]` — architecture decision already made

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: [8] | Blocked By: [1, 2]

  **References** (executor has NO interview context — be exhaustive):
  - Pattern: `README.md` — architecture and deploy sections
  - Pattern: `docs/workflow-reference.md` — workflow sequence docs
  - Pattern: `docs/sync-system.md` — local sync semantics
  - Pattern: `docs/local-dev-setup.md` — local execution conventions

  **Acceptance Criteria** (agent-executable only):
  - [ ] `grep -n "local build\|direct deploy" README.md docs/*.md` shows primary-flow language
  - [ ] `grep -n "GitHub-hosted\|private/local WordPress" README.md docs/*.md` shows reachability caveat

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```bash
  Scenario: Primary flow is local deploy
    Tool: Bash
    Steps: grep for explicit "primary"/"default" local deploy language
    Expected: at least one clear statement in README and one in docs
    Evidence: .sisyphus/evidence/task-4-primary-flow-docs.txt

  Scenario: Conflicting old instructions detected
    Tool: Bash
    Steps: grep for `gh workflow run deploy.yml` and fail if found as active guidance
    Expected: zero active-guidance matches
    Evidence: .sisyphus/evidence/task-4-primary-flow-docs-error.txt
  ```

  **Commit**: YES | Message: `docs(deploy): make local direct deploy the primary path` | Files: [README.md, docs/workflow-reference.md, docs/local-dev-setup.md, docs/sync-system.md]

- [x] 5. Update webhook and trigger documentation for manual production mode

  **What to do**: Clarify that `scripts/wp-webhook.php` repository-dispatch behavior is no longer the canonical production deploy trigger under manual mode; keep as optional/legacy note only if retained.
  **Must NOT do**: Do not leave implicit auto-deploy promises in docs.

  **Recommended Agent Profile**:
  - Category: `writing` — Reason: behavior clarification across docs
  - Skills: `[]` — no external docs dependency
  - Omitted: `[deep]` — scope is documentation alignment

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: [8] | Blocked By: [1]

  **References** (executor has NO interview context — be exhaustive):
  - Pattern: `scripts/wp-webhook.php` — repository_dispatch event behavior
  - Pattern: `README.md` — deploy trigger references
  - Pattern: `docs/sync-system.md` — webhook terminology and flow

  **Acceptance Criteria** (agent-executable only):
  - [ ] `grep -n "wordpress-publish\|repository_dispatch" README.md docs/*.md` shows explicit non-primary/legacy framing
  - [ ] `grep -n "manual" README.md docs/*.md` shows manual deploy operation language

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```bash
  Scenario: Trigger semantics clarified
    Tool: Bash
    Steps: grep trigger terms and inspect adjacent phrasing
    Expected: docs do not describe repository_dispatch as default production path
    Evidence: .sisyphus/evidence/task-5-trigger-docs.txt

  Scenario: Ambiguous auto-deploy claim detected
    Tool: Bash
    Steps: grep for phrases like "automatic deploy on publish" in production sections
    Expected: no ambiguous claims remain
    Evidence: .sisyphus/evidence/task-5-trigger-docs-error.txt
  ```

  **Commit**: YES | Message: `docs(triggers): align webhook trigger guidance with manual deploy mode` | Files: [README.md, docs/sync-system.md]

- [x] 6. Correct image optimization documentation to match implementation

  **What to do**: Update `docs/image-optimization.md` so described formats and behavior match current `scripts/fetch-images.rb` implementation (WebP-focused flow and current watermark/processing behavior).
  **Must NOT do**: Do not change image-processing code in this task; only align docs to current behavior.

  **Recommended Agent Profile**:
  - Category: `writing` — Reason: implementation-doc alignment
  - Skills: `[]` — local source files provide truth
  - Omitted: `[artistry]` — no creative redesign needed

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: [8] | Blocked By: [3]

  **References** (executor has NO interview context — be exhaustive):
  - Pattern: `docs/image-optimization.md` — current docs requiring correction
  - Pattern: `scripts/fetch-images.rb` — implementation source of truth
  - Pattern: `hugo-site/layouts/partials/image.html` — rendering assumptions

  **Acceptance Criteria** (agent-executable only):
  - [ ] `grep -n "WebP" docs/image-optimization.md` returns behavior-consistent references
  - [ ] `grep -n "AVIF" docs/image-optimization.md` has zero matches unless explicitly marked future work
  - [ ] `grep -n "fallback" docs/image-optimization.md` does not contradict current rendering behavior

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```bash
  Scenario: Docs reflect implemented image formats
    Tool: Bash
    Steps: grep for format mentions in docs and compare with script behavior terms
    Expected: no contradiction between docs and script/partial
    Evidence: .sisyphus/evidence/task-6-image-doc-alignment.txt

  Scenario: Legacy AVIF claims detected
    Tool: Bash
    Steps: grep for AVIF claims and fail if presented as active behavior
    Expected: zero active AVIF-behavior claims
    Evidence: .sisyphus/evidence/task-6-image-doc-alignment-error.txt
  ```

  **Commit**: YES | Message: `docs(images): align optimization docs with current implementation` | Files: [docs/image-optimization.md]

- [x] 7. Add production runbook for local deploy operations

  **What to do**: Create/extend runbook section with exact steps for initial setup, regular deploy, failure handling, rollback strategy, and credential handling for local operators.
  **Must NOT do**: Do not introduce production rollback claims without executable commands.

  **Recommended Agent Profile**:
  - Category: `writing` — Reason: operational procedure documentation
  - Skills: `[]` — existing docs provide command patterns
  - Omitted: `[playwright]` — non-UI operations

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: [8] | Blocked By: []

  **References** (executor has NO interview context — be exhaustive):
  - Pattern: `docs/workflow-reference.md` — command sequencing baseline
  - Pattern: `docs/local-dev-setup.md` — env and troubleshooting style
  - External: `https://developers.cloudflare.com/pages/platform/limits/` — operational limits (file count, file size)

  **Acceptance Criteria** (agent-executable only):
  - [ ] `grep -n "deploy-local.sh" docs/*.md README.md` shows runbook command inclusion
  - [ ] `grep -n "rollback\|failure\|troubleshoot" docs/*.md` shows explicit operator procedures

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```bash
  Scenario: Runbook includes happy path and failure path
    Tool: Bash
    Steps: grep runbook for deploy command and failure/rollback sections
    Expected: all required sections present
    Evidence: .sisyphus/evidence/task-7-runbook.txt

  Scenario: Missing rollback procedure detected
    Tool: Bash
    Steps: fail check when rollback keyword absent
    Expected: non-zero exit if rollback instructions missing
    Evidence: .sisyphus/evidence/task-7-runbook-error.txt
  ```

  **Commit**: YES | Message: `docs(runbook): add local production deploy operations guide` | Files: [docs/workflow-reference.md, docs/local-dev-setup.md, README.md]

- [x] 8. Execute consistency audit and enforce single-primary deployment narrative

  **What to do**: Run repo-wide grep checks to ensure all deployment docs, scripts, and references consistently point to local manual production deploy as primary and do not leave stale hosted-fetch guidance.
  **Must NOT do**: Do not leave unresolved contradictions for follow-up unless explicitly marked out-of-scope in a dedicated note.

  **Recommended Agent Profile**:
  - Category: `unspecified-low` — Reason: cross-file consistency validation
  - Skills: `[]` — command-based audit only
  - Omitted: `[librarian]` — no external research required

  **Parallelization**: Can Parallel: NO | Wave 2 | Blocks: [] | Blocked By: [2, 3, 4, 5, 6, 7]

  **References** (executor has NO interview context — be exhaustive):
  - Pattern: `README.md` — primary architecture statement
  - Pattern: `docs/*.md` — deployment and image behavior references
  - Pattern: `scripts/deploy-local.sh` — canonical command contract

  **Acceptance Criteria** (agent-executable only):
  - [ ] `grep -R "gh workflow run deploy.yml" README.md docs || true` returns no active-guidance references
  - [ ] `grep -R "local build\|direct deploy\|deploy-local.sh" README.md docs` returns canonical-path references
  - [ ] `grep -R "wordpress/wp-json" README.md docs` does not imply hosted CI runner reachability by default

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```bash
  Scenario: Narrative consistency passes
    Tool: Bash
    Steps: run full grep audit for primary-path and stale-guidance terms
    Expected: stale guidance absent; primary guidance present
    Evidence: .sisyphus/evidence/task-8-consistency-audit.txt

  Scenario: Stale hosted workflow guidance found
    Tool: Bash
    Steps: intentionally include stale phrase check in fail-fast script
    Expected: non-zero exit if stale phrase appears
    Evidence: .sisyphus/evidence/task-8-consistency-audit-error.txt
  ```

  **Commit**: YES | Message: `docs(architecture): enforce single primary local deploy narrative` | Files: [README.md, docs/*, scripts/deploy-local.sh]

## Final Verification Wave (4 parallel agents, ALL must APPROVE)
- [x] F1. Plan Compliance Audit — oracle
- [x] F2. Code Quality Review — unspecified-high
- [x] F3. Real Manual QA — unspecified-high (+ playwright if UI)
- [x] F4. Scope Fidelity Check — deep

## Commit Strategy
- Commit 1: remove old hosted deploy workflow and add local deploy wrapper
- Commit 2: documentation alignment (README + docs/*.md)
- Commit message format: Conventional Commits (`feat`, `docs`, `chore`)

## Success Criteria
- Private/local WordPress users can deploy without exposing WP API publicly.
- Repository no longer implies hosted CI can directly fetch from private WP by default.
- One primary production deploy path is documented and executable.
- Image behavior documentation matches current implementation.
