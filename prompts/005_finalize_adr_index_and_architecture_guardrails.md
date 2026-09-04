---
id: '005'
title: Finalize ADR index and architecture guardrails
phase: 00 Governance and bootstrap
recommended_reasoning: medium
recommended_model: strongest_available_codex
depends_on:
- '004'
status: pending
---

# Prompt 005 — Finalize ADR index and architecture guardrails

## Codex execution settings

- **Recommended reasoning:** `medium`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `004`
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
ruby tracking/scripts/prompt_tracker.rb start 005
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

Create a navigable architecture decision index and make the accepted foundational decisions visible in pull requests, code review and future prompt execution.

## Required references

- `docs/adr`
- `docs/02_ARCHITECTURE.md`
- `AGENTS.md`

## Required work

1. Review ADRs 0001–0010 against the initialized repository and update facts that changed during prompts 001–004 without silently changing the intent.
2. Create `docs/adr/README.md` containing status definitions, decision lifecycle, supersession rules, owner/review fields and an indexed summary of every ADR.
3. Add an ADR template with Context, Decision, Alternatives, Security/Privacy, Operations, Consequences and Revisit Triggers sections.
4. Create a lightweight pull-request checklist that asks whether tenancy, permissions, entitlements, quotas, migrations, provider contracts, security boundaries and ADRs were affected.
5. Add repository links from the main README and implementation docs.
6. Record any unresolved architecture discrepancy in `tracking/DECISIONS.md` or `tracking/BLOCKERS.md` rather than guessing.

## Required verification

- Check every ADR link from the index resolves.
- Run markdown/link checks available in the repository.
- Run tracker validation and the existing test suite.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Review ADRs 0001–0010 against the initialized repository and update facts that changed during prompts 001–004 without silently changing the intent.
- [ ] Create `docs/adr/README.md` containing status definitions, decision lifecycle, supersession rules, owner/review fields and an indexed summary of every ADR.
- [ ] Add an ADR template with Context, Decision, Alternatives, Security/Privacy, Operations, Consequences and Revisit Triggers sections.
- [ ] Create a lightweight pull-request checklist that asks whether tenancy, permissions, entitlements, quotas, migrations, provider contracts, security boundaries and ADRs were affected.
- [ ] Add repository links from the main README and implementation docs.
- [ ] Record any unresolved architecture discrepancy in `tracking/DECISIONS.md` or `tracking/BLOCKERS.md` rather than guessing.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not mark an ADR superseded without a replacement decision.
- Do not turn preferences into mandatory rules without rationale.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 005 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 005 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 005
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
