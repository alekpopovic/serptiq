# ADR 0004 — Separate RBAC, entitlements and quotas

- Status: Accepted
- Date: 2026-09-04
- Owners: Authorization, Entitlements, Usage
- Last reviewed: 2026-09-04 (Prompt 039)

## Context

A member's authority, the organization's purchased features and the organization's remaining usage answer different questions. Tying all three to plan names causes privilege errors, brittle upgrades and inaccurate billing.

## Decision

Evaluate protected actions through independent controls:

```text
permission at scope
AND typed entitlement
AND available quota/reservation
AND valid resource state
```

Use stable keys and immutable plan versions. Record usage in an append-only ledger and use atomic reservations for asynchronous variable-cost work.

## Consequences

- Plans can change without rewriting authorization.
- Custom roles cannot unlock unpaid features.
- Quota concurrency and reconciliation require dedicated domain code/tests.
- Every billable feature must document permission, entitlement and meter keys.

## Implementation status

Prompt 038 implements the strict typed definition/value catalog, tenant-consistent active-subscription
projection, audited organization overrides and fail-closed resolver with provenance. Prompt 039 implements
immutable weighted meter/rate history, deterministic UTC/provider windows, append-only usage/correction
events and snapshot-based read models. Atomic quota reservations and the unified orchestration decision remain
Prompt 040–042 work; neither implemented module collapses these independent controls.
