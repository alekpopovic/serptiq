# ADR 0003 — Application-owned social authentication

- Status: Accepted
- Date: 2026-09-04

## Context

The MVP needs Google OpenID Connect and GitHub OAuth sign-in, not a general OAuth authorization server. Large authentication gems can obscure provider validation and introduce features outside the required scope.

## Decision

Implement provider adapters over a small application-owned authentication domain using server-side sessions. Validate state, nonce where applicable, PKCE, exact redirect URIs, token signatures/claims and stable provider subject IDs. Do not use Devise, OmniAuth or Doorkeeper in the MVP.

## Consequences

- Security-critical protocol code is explicit and well tested.
- The team owns patching and provider behavior changes.
- Adapter contract tests and security review are mandatory.
- Adding password authentication or becoming an OAuth provider requires a separate ADR.
