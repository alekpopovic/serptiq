---
id: 084
title: Implement structured-data extraction and validation rules
phase: 07 Rules, findings and issue workflow
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 083
status: pending
---

# Prompt 084 — Implement structured-data extraction and validation rules

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `083`
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
ruby tracking/scripts/prompt_tracker.rb start 084
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

Validate bounded JSON-LD/microdata/RDFa facts for syntax and supported search-feature requirements while preserving source/version provenance.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/12_SOURCE_REFERENCES.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Parse JSON-LD with depth/key/string/byte limits and no remote context/network resolution.
2. Represent extracted structured data as normalized bounded facts and store full source only as protected artifact when needed.
3. Implement syntax, missing required/recommended property, invalid value/type, duplicate entity and mismatch-with-visible-content indicators where evidence supports them.
4. Separate schema.org vocabulary validity from a provider's supported rich-result eligibility.
5. Version provider-specific supported-type requirements and cite source/effective date in rule metadata.
6. Treat unknown/custom types safely and avoid marking extra schema as inherently beneficial.
7. Escape all values in UI and provide source locators.
8. Create fixture suite for malicious/deep/cyclic-like JSON and mixed markup.

## Required verification

- Valid/invalid/boundary golden fixtures.
- Depth/size/parser-bomb and no-network tests.
- Provider-version change tests.
- Visible-content mismatch tests with explicit confidence.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Parse JSON-LD with depth/key/string/byte limits and no remote context/network resolution.
- [ ] Represent extracted structured data as normalized bounded facts and store full source only as protected artifact when needed.
- [ ] Implement syntax, missing required/recommended property, invalid value/type, duplicate entity and mismatch-with-visible-content indicators where evidence supports them.
- [ ] Separate schema.org vocabulary validity from a provider's supported rich-result eligibility.
- [ ] Version provider-specific supported-type requirements and cite source/effective date in rule metadata.
- [ ] Treat unknown/custom types safely and avoid marking extra schema as inherently beneficial.
- [ ] Escape all values in UI and provide source locators.
- [ ] Create fixture suite for malicious/deep/cyclic-like JSON and mixed markup.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Never resolve remote JSON-LD contexts.
- Do not promise rich results or ranking eligibility.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 084 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 084 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 084
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
