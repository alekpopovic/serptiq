# AGENTS.md — SearchOps implementation contract

This repository is built through sequential numbered prompts. These rules apply to every agent and every prompt.

## Required reading order

Before changing code, read:

1. this file;
2. `tracking/state.json`;
3. the active prompt;
4. all prompt dependencies and their result summaries;
5. the relevant documents under `docs/`;
6. existing code and tests in the affected module.

Do not implement from the prompt title alone.

## Execution tracking

Use:

```bash
ruby tracking/scripts/prompt_tracker.rb start <ID>
ruby tracking/scripts/prompt_tracker.rb complete <ID> --summary "..." --tests "..."
ruby tracking/scripts/prompt_tracker.rb block <ID> --reason "..."
```

Only one prompt may be `in_progress`. Do not skip unresolved dependencies. Do not edit another prompt's status manually unless repairing the tracker itself.

## Git completion workflow

Every numbered prompt must end with its own Git commit and a successful push of the current branch. After the prompt's implementation, required verification, tracker validation and tracker completion are finished:

1. inspect `git status` and the complete diff;
2. stage only files created or changed for the active prompt, including its tracker/result files, with `git add`;
3. create a commit whose message identifies the prompt, for example `Prompt 024: implement organization tenant context`;
4. push the current branch to its configured upstream; when the branch has no upstream, use the intended repository remote and set the upstream explicitly;
5. record the commit SHA, branch and actual push outcome in the final response.

Do not stage or commit unrelated user changes. Never use force-push to satisfy this workflow. Before completing a prompt, confirm that a repository remote, intended branch and push authentication are available. If commit or push cannot succeed, do not start the next prompt; report the exact blocker and resume the same completion workflow after it is resolved.

## Scope and quality

- Implement only the active prompt plus the smallest supporting changes required.
- Prefer Rails conventions and standard-library capabilities.
- Keep the application a modular monolith.
- Use PostgreSQL for application data, queues, caching, and Action Cable.
- Use Minitest, fixtures, test helpers, and Rails system tests.
- Add database constraints in addition to model validations.
- Use service objects only for real orchestration or domain operations, not as a default wrapper around every model method.
- Prefer explicit, immutable value objects for domain decisions.
- Avoid callbacks for cross-module workflows.
- Emit domain events only through the documented outbox/event mechanism.
- Never use `default_scope` for tenant isolation.
- Never authorize solely in views.
- Never gate features by plan name.
- Never store raw access tokens, refresh tokens, signing secrets, or provider credentials unencrypted.
- Never fetch a user-controlled URL without the crawler network-safety policy.
- Never execute page JavaScript in the web process.
- Never store large HTML, screenshots, HAR, Lighthouse JSON, or rendered DOM blobs in PostgreSQL.

## Multi-tenant invariant

Every tenant-owned row must be reachable from exactly one `organization_id`, directly or by an enforced parent relationship. Every request must establish `Current.user`, `Current.organization`, and `Current.membership` only after membership validation. Background jobs must receive explicit tenant identifiers and re-authorize their target records.

## Access decision invariant

A billable or privileged action succeeds only when all applicable checks pass:

```text
authenticated user
AND active membership
AND permission for the requested scope
AND enabled organization entitlement
AND available quota/reservation
AND valid resource state
```

## Security baseline

- Validate OAuth/OIDC state, nonce, redirect URI, issuer, audience, signature, expiry, and PKCE where applicable.
- Rotate the Rails session after authentication and privilege changes.
- Verify webhook signatures against the exact raw request body.
- Make external event ingestion idempotent.
- Apply request size, rate, timeout, and retry limits.
- Block private, loopback, link-local, multicast, reserved, metadata, and otherwise non-public network destinations in crawler traffic.
- Re-resolve and re-validate every redirect destination.
- Treat HTML, JavaScript, JSON-LD, XML, images, manifests, and store metadata as untrusted input.
- Redact credentials and personal data from logs and artifacts.

## Database rules

- Prefer UUID primary keys for tenant and externally referenced domain records.
- Use integer/bigint IDs for high-volume internal scan rows when materially more efficient.
- Add foreign keys, nullability, checks, and unique indexes.
- Use partial indexes where lifecycle state makes them appropriate.
- Use optimistic or explicit locking for subscription, quota, and workflow transitions.
- Design high-volume retention and partitioning before data volume becomes an emergency.
- Migrations must be safe for production-sized tables; document any lock risk.

## Testing requirements

Each prompt must add tests at the correct layer:

- model/domain unit tests;
- policy and service tests;
- request/integration tests;
- job retry/idempotency tests;
- system tests for critical user flows;
- security regression tests;
- tenant-isolation tests;
- contract tests for external adapters.

Tests must assert negative paths and cross-tenant denial, not only happy paths.

## Completion response

The agent's final response for each prompt must contain:

1. concise implementation summary;
2. files changed;
3. migrations and operational impact;
4. exact test/lint/security commands run and their outcomes;
5. assumptions or unresolved risks;
6. tracker status.
7. commit SHA, branch and push result.

Do not claim checks passed when they were not run.
