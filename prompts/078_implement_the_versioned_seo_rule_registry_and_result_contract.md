---
id: 078
title: Implement the versioned SEO rule registry and result contract
phase: 07 Rules, findings and issue workflow
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '077'
status: pending
---

# Prompt 078 — Implement the versioned SEO rule registry and result contract

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `077`
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
ruby tracking/scripts/prompt_tracker.rb start 078
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

Create the deterministic rule-engine foundation that loads validated rule metadata, declares inputs/applicability and emits explainable versioned results.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `config_blueprints/seo_rules.yml`
- `schemas/seo_rule_result.schema.json`
- `docs/adr/0009_versioned_rule_engine_and_evidence.md`

## Required work

1. Create a rule registry with stable key, semantic implementation version, category, supported property/source types, required inputs, default severity/confidence, title, description, remediation and verification method.
2. Load/validate `config_blueprints/seo_rules.yml`; detect duplicate/unknown/deprecated keys and unsafe removal of rules present in historical findings.
3. Define the normalized rule result matching `schemas/seo_rule_result.schema.json`, including applicability and unknown—not only pass/fail.
4. Create a base rule interface that is pure over versioned input snapshots and cannot perform arbitrary network/database writes.
5. Implement deterministic evidence locators/fingerprints and bounded sanitized values.
6. Record engine/catalog checksum and source versions with each analysis run.
7. Create shared contract tests and a fixture/golden-output workflow.
8. Expose rule catalog/read-only details in the application.

## Required verification

- Validate all 96 configured rule definitions.
- Run shared contract tests against a sample rule.
- Test deterministic output/fingerprint across repeated runs.
- Test historical rule-removal/version-change safety.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create a rule registry with stable key, semantic implementation version, category, supported property/source types, required inputs, default severity/confidence, title, description, remediation and verification method.
- [ ] Load/validate `config_blueprints/seo_rules.yml`; detect duplicate/unknown/deprecated keys and unsafe removal of rules present in historical findings.
- [ ] Define the normalized rule result matching `schemas/seo_rule_result.schema.json`, including applicability and unknown—not only pass/fail.
- [ ] Create a base rule interface that is pure over versioned input snapshots and cannot perform arbitrary network/database writes.
- [ ] Implement deterministic evidence locators/fingerprints and bounded sanitized values.
- [ ] Record engine/catalog checksum and source versions with each analysis run.
- [ ] Create shared contract tests and a fixture/golden-output workflow.
- [ ] Expose rule catalog/read-only details in the application.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Rules do not mutate workflow state directly.
- Never reduce unavailable input to an automatic pass.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 078 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 078 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 078
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
