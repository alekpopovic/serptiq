---
id: '119'
title: Run final acceptance, pilot readiness and production MVP release review
phase: 11 Production hardening and launch
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '118'
status: pending
---

# Prompt 119 — Run final acceptance, pilot readiness and production MVP release review

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `118`
- **Execution mode:** one prompt at a time; inspect and modify the real repository; do not simulate completion

The reasoning label is a minimum recommendation for this task. Use deeper reasoning when implementation evidence demands it. Never lower rigor for authentication, authorization, billing, concurrency, tenant isolation, outbound networking, browser execution, migrations or production safety.

## Mandatory operating contract

Before writing code:

1. Read `AGENTS.md`.
2. Read `tracking/state.json` and the result summaries for all dependencies.
3. Read this entire prompt and the referenced documents below.
4. Inspect the current code, tests, schema, migrations, configuration and Git diff. The repository—not an assumed greenfield state—is the source of truth.
5. Start the prompt:

```bash
ruby tracking/scripts/prompt_tracker.rb start 119
```

If the tracker refuses, stop and resolve the stated dependency/current-state problem honestly. Do not edit `tracking/state.json` by hand to bypass it.

During implementation:

- Follow the modular-monolith, PostgreSQL-only, native-session and Solid-stack decisions.
- Do not add Devise, OmniAuth, Doorkeeper, Sidekiq, Redis, Elasticsearch or Kubernetes unless a later accepted ADR explicitly supersedes the blueprint.
- Preserve tenant isolation and enforce access in backend/domain boundaries, not only in views.
- Add database constraints as well as model validation.
- Treat every external payload and customer-controlled value as hostile.
- Keep unrelated refactors out of this prompt.
- Do not hide failing tests, skipped checks, assumptions or security limitations.

## Objective

Perform an evidence-based end-to-end review of every milestone, close or explicitly block gaps, and produce the release/pilot handoff without pretending incomplete work is done.

## Required references

- `docs/01_PRD_V1.md`
- `docs/09_TEST_STRATEGY.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/11_ROADMAP_AND_DEFINITION_OF_DONE.md`

## Required work

1. Validate all 120 prompt states, result records, dependencies, documentation/config schemas and repository cleanliness.
2. Run the complete CI-equivalent suite: lint, unit/integration/job/system, tenant isolation, auth, billing, crawler/browser security, assets and production image smoke.
3. Execute end-to-end staging journeys from social login and organization creation through billing, verified crawl, issue verification, integrations, mobile links, release guard, report and API/webhook.
4. Review every launch-scope requirement and non-functional gate in PRD/roadmap with evidence links; mark pass, fail, accepted risk or out of scope.
5. Create `docs/implementation/PRODUCTION_MVP_ACCEPTANCE.md` with versions, test commands/results, known limitations, residual risks, rollback, support/on-call and pilot criteria.
6. Verify legal/commercial placeholders—terms, privacy, retention, billing/tax/provider agreements—are assigned for qualified review and not falsely claimed complete.
7. Create pilot onboarding/runbook and monitoring checklist for the first organizations.
8. Make a factual go/no-go recommendation. Do not deploy automatically.

## Required verification

- Run `ruby tracking/scripts/prompt_tracker.rb validate` and archive status output.
- Run every required CI/security/system command and record exact outcomes.
- Run production image/container/Kamal configuration smoke.
- Review acceptance file against `docs/11_ROADMAP_AND_DEFINITION_OF_DONE.md`.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Validate all 120 prompt states, result records, dependencies, documentation/config schemas and repository cleanliness.
- [ ] Run the complete CI-equivalent suite: lint, unit/integration/job/system, tenant isolation, auth, billing, crawler/browser security, assets and production image smoke.
- [ ] Execute end-to-end staging journeys from social login and organization creation through billing, verified crawl, issue verification, integrations, mobile links, release guard, report and API/webhook.
- [ ] Review every launch-scope requirement and non-functional gate in PRD/roadmap with evidence links; mark pass, fail, accepted risk or out of scope.
- [ ] Create `docs/implementation/PRODUCTION_MVP_ACCEPTANCE.md` with versions, test commands/results, known limitations, residual risks, rollback, support/on-call and pilot criteria.
- [ ] Verify legal/commercial placeholders—terms, privacy, retention, billing/tax/provider agreements—are assigned for qualified review and not falsely claimed complete.
- [ ] Create pilot onboarding/runbook and monitoring checklist for the first organizations.
- [ ] Make a factual go/no-go recommendation. Do not deploy automatically.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not mark this prompt complete if any required test is unrun without a documented blocking reason.
- Do not deploy to production as an implicit step of acceptance.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 119 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 119 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 119
Status: completed or blocked
Implemented:
Key files:
Migrations:
Tests and actual results:
Security/tenancy review:
Remaining risks:
Next eligible prompt:
```

Never claim completion based only on generated code or an unexecuted test plan.
