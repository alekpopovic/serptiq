# Architecture Decision Records

ADRs record durable choices that shape more than one feature or impose lasting
security, data or operational constraints. Accepted ADRs govern implementation
until a later accepted ADR explicitly supersedes them.

## Status definitions

- `Proposed`: open for review and not binding.
- `Accepted`: approved and binding for implementation.
- `Superseded`: replaced by a named, accepted later ADR; retained as history.
- `Rejected`: considered and deliberately not adopted.
- `Deprecated`: still present for compatibility, with removal/replacement work
  identified.

## Required metadata

Every ADR names its status, decision date, accountable owner(s), last review,
and any superseded/superseding record. Owners maintain the decision and approve
material factual corrections. `Last reviewed` identifies the date and prompt or
review that checked the ADR against the repository; it is not a claim that all
planned implementation is finished.

## Decision lifecycle

1. Copy [`ADR_TEMPLATE.md`](./ADR_TEMPLATE.md), allocate the next four-digit ID,
   set status to `Proposed`, and name owners and reviewers.
2. Describe forces, alternatives, security/privacy, operations, consequences
   and objective revisit triggers. Link measurements or external contracts.
3. Obtain the affected module and architecture/security reviews. Change status
   to `Accepted` only when the decision and rollout ownership are clear.
4. Link the ADR from this index and from affected implementation documents or
   pull requests. Track partial implementation honestly.
5. Re-review when a trigger occurs. Correct factual metadata in place, but put a
   materially different choice in a new ADR.

To supersede a decision, the replacement must be accepted, name every ADR it
supersedes and describe migration/rollback. Each old ADR then changes to
`Superseded` and links `Superseded by` to the replacement. Never delete or
rewrite the old rationale, and never mark a record superseded without its
replacement.

## Index

| ADR | Status | Owners | Last review | Implementation |
|---|---|---|---|---|
| [0001 — Modular Rails monolith](./0001_modular_rails_monolith.md) | Accepted | Architecture | 2026-09-04 / Prompt 005 | Boundary checker active |
| [0002 — PostgreSQL and Solid stack](./0002_postgresql_and_solid_stack.md) | Accepted | Platform | 2026-09-04 / Prompt 007 | Four Solid-backed connections and isolated worker roles active |
| [0003 — Native social authentication](./0003_native_social_authentication.md) | Accepted | Identity, Security | 2026-09-04 / Prompt 005 | Planned 014–023 |
| [0004 — Separate RBAC, entitlements and quotas](./0004_separate_rbac_entitlements_and_quotas.md) | Accepted | Authorization, Entitlements, Usage | 2026-09-04 / Prompt 040 | Entitlements, ledger and quota reservations implemented 038–040; unified access pending 042 |
| [0005 — Object storage for large artifacts](./0005_object_storage_for_large_artifacts.md) | Accepted | Platform, Crawling | 2026-09-04 / Prompt 005 | Typed settings active; adapter pending 070 |
| [0006 — SSRF-safe crawler boundary](./0006_ssrf_safe_crawler_boundary.md) | Accepted | Security, Crawling | 2026-09-04 / Prompt 005 | Planned 068–069 and 076 |
| [0007 — Isolated browser workers](./0007_isolated_browser_workers.md) | Accepted | Security, Crawling | 2026-09-04 / Prompt 005 | Planned 075–076 |
| [0008 — Provider-neutral billing](./0008_provider_neutral_billing.md) | Accepted | Billing | 2026-09-04 / Prompt 005 | Planned 043–049 |
| [0009 — Versioned rules and evidence](./0009_versioned_rule_engine_and_evidence.md) | Accepted | Analysis, Findings | 2026-09-04 / Prompt 005 | Planned 078–089 |
| [0010 — Docker and Kamal deployment](./0010_docker_and_kamal_deployment.md) | Accepted | Platform | 2026-09-04 / Prompt 005 | Generated scaffold; hardening pending 116 |

Run `script/check_adr_index` after adding or changing an ADR. It verifies that
the index and ADR files correspond, every indexed link resolves, required
metadata exists, statuses are known, and the template retains required sections.
