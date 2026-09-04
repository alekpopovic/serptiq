---
id: 086
title: Implement AI crawler policy matrix
phase: 07 Rules, findings and issue workflow
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- 085
status: pending
---

# Prompt 086 — Implement AI crawler policy matrix

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `085`
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
ruby tracking/scripts/prompt_tracker.rb start 086
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

Report explicit crawler-access policies for major configured bots while keeping search inclusion, training use and user-triggered fetch semantics separate.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/12_SOURCE_REFERENCES.md`

## Required work

1. Create versioned crawler-agent definitions from current official documentation, including distinct OpenAI agents where behavior differs.
2. Evaluate robots groups/directives for each configured agent plus generic user agent.
3. Show allow/deny/unknown at origin/path with exact matched rule and robots snapshot date.
4. Implement conflict/missing-policy findings as informational/recommendation levels rather than a fabricated GEO score.
5. Separate technical accessibility from likely citation, inclusion, ranking or training outcomes.
6. Allow catalog updates without rewriting historical reports by snapshotting agent definitions.
7. Create policy matrix UI and export data.
8. Add source/effective-date metadata.

## Required verification

- Robots precedence fixtures for multiple agents.
- Historical agent-definition version tests.
- Customer-facing language tests/snapshots avoiding guarantees.
- Unknown/unavailable robots behavior tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create versioned crawler-agent definitions from current official documentation, including distinct OpenAI agents where behavior differs.
- [ ] Evaluate robots groups/directives for each configured agent plus generic user agent.
- [ ] Show allow/deny/unknown at origin/path with exact matched rule and robots snapshot date.
- [ ] Implement conflict/missing-policy findings as informational/recommendation levels rather than a fabricated GEO score.
- [ ] Separate technical accessibility from likely citation, inclusion, ranking or training outcomes.
- [ ] Allow catalog updates without rewriting historical reports by snapshotting agent definitions.
- [ ] Create policy matrix UI and export data.
- [ ] Add source/effective-date metadata.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not conflate OAI-SearchBot, GPTBot and user-triggered agents.
- Do not claim access permission guarantees AI visibility.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 086 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 086 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 086
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
