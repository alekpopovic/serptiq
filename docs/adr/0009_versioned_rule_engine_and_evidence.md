# ADR 0009 — Version SEO rules and persist evidence

- Status: Accepted
- Date: 2026-09-04
- Owners: Analysis, Findings
- Last reviewed: 2026-09-04 (Prompt 005)

## Context

SEO/provider standards evolve. A finding without rule version, source and evidence cannot be reproduced, explained or safely compared across scans.

## Decision

Every rule has a stable key, semantic implementation version, applicability, inputs, default severity/confidence, evidence schema, remediation and verification method. Results persist rule version and deterministic fingerprint. Rule changes may create migrations or comparison boundaries.

## Consequences

- Historical reports remain interpretable.
- Golden fixtures require review when a rule changes.
- A single opaque SEO score is not the source of truth.
- Provider-specific rule changes cite their effective source/version.
