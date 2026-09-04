---
id: 029
title: Seed permissions and immutable system roles
phase: 03 Organizations, membership and RBAC
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- 028
status: pending
---

# Prompt 029 — Seed permissions and immutable system roles

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `028`
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
ruby tracking/scripts/prompt_tracker.rb start 029
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

Implement the 57-key permission catalog and immutable system role definitions from the blueprint as version-controlled, repeatable data.

## Required references

- `docs/04_RBAC_PERMISSION_MATRIX.md`
- `config_blueprints/permissions.yml`
- `docs/03_ERD.md`

## Required work

1. Create permissions, roles and role-permission relationships with stable keys and organization/system ownership rules.
2. Load the catalog from `config_blueprints/permissions.yml` through an idempotent sync task that adds/updates metadata but never silently renames/removes in-use keys.
3. Implement the system roles Owner, Organization Admin, Billing Admin, SEO Lead, Developer, Content Editor, Analyst and Viewer with the documented grants.
4. Mark system-role grants immutable through application operations.
5. Define catalog validation for duplicate keys, unknown grants and permissions that lack descriptions/category/scope.
6. Record catalog revision/checksum for auditability.
7. Create an admin-readable permission matrix page or development report.

## Required verification

- Config schema/semantic validation tests.
- Idempotent sync test and removal/rename safety test.
- System-role immutability tests.
- Compare generated grants to `docs/04_RBAC_PERMISSION_MATRIX.md`.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create permissions, roles and role-permission relationships with stable keys and organization/system ownership rules.
- [ ] Load the catalog from `config_blueprints/permissions.yml` through an idempotent sync task that adds/updates metadata but never silently renames/removes in-use keys.
- [ ] Implement the system roles Owner, Organization Admin, Billing Admin, SEO Lead, Developer, Content Editor, Analyst and Viewer with the documented grants.
- [ ] Mark system-role grants immutable through application operations.
- [ ] Define catalog validation for duplicate keys, unknown grants and permissions that lack descriptions/category/scope.
- [ ] Record catalog revision/checksum for auditability.
- [ ] Create an admin-readable permission matrix page or development report.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Never authorize by role name directly.
- Do not delete a permission merely because it disappeared from YAML.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 029 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 029 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 029
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
