# Search Console ownership verification

Prompt 056 lets an exact Google Search Console property serve as an observed ownership proof while keeping
Google login, SearchOps membership and separately consented provider access distinct.

## Connection boundary

`integration_connections` now provides a credential-free metadata foundation for this verification flow. A
connection is organization-bound, records the connecting membership, exact external account identifier,
allowlisted scopes, lifecycle, consent time and monotonically increasing credential revision. Registration
accepts only a `search_console_oauth` consent grant containing the least Search Console read-only scope. The
opaque consent reference is stored only as a SHA-256 digest; access/refresh tokens are not accepted or stored by
this prompt. Encrypted credentials, refresh locking and the complete connection lifecycle remain assigned to
Prompt 091, while the OAuth callback and mapping-management UI remain assigned to Prompt 092.

A Google sign-in identity is never converted into this connection. Registering or reauthorizing connection
metadata requires `integrations.manage`. Selecting, viewing or attempting Search Console proof additionally
requires `properties.verify` for the exact property scope. The Verification domain sees only immutable public
connection projections; composite foreign keys prevent a connection from crossing organizations.

## Exact provider-property rules

The provider list exists only in memory for the current authorized request, is capped at 500 entries and is
discarded after matching. A selected option is carried by a ten-minute signed value containing only the exact
connection and external property identifiers. Issuance fetches the provider list again before persisting the
selection, and each attempt repeats the exact lookup.

- A URL-prefix identifier must be the canonical origin plus one trailing slash, such as
  `https://example.com/`. Scheme, ASCII-IDNA host and effective port must all equal the SearchOps environment;
  provider path prefixes are not accepted for origin ownership.
- A domain identifier must be canonical `sc-domain:<ascii-host>` and matches only the exact SearchOps host.
  It may span HTTP/HTTPS for that host, but SearchOps does not infer sibling or parent/subdomain ownership.
- Only Google's `siteOwner` permission is ownership evidence. Full, restricted and unverified user access are
  recorded as provider observations but cannot verify control.
- Duplicate entries for one selected identifier are ambiguous and fail closed. A second exact eligible
  connection/property pair is also presented as ambiguous rather than silently choosing an account.

The challenge stores the exact connection ID/revision, provider identifier/type, reported permission and check
time. It does not store the broader property list or any credential. Attempt evidence remains bounded booleans;
provider account IDs, lists and payloads do not enter evidence or UI errors.

## Failure and revalidation

Stable categories distinguish revoked scope, inaccessible property, provider outage, ambiguous response,
no exact match, insufficient owner permission and changed connection revision. Customer text calls these
Google-known observations, never a live-fetch or permanent ownership guarantee.

The existing origin trigger revokes proof when the property origin changes. A new PostgreSQL trigger revokes
pending/verified Search Console challenges and resets the primary property summary when the selected connection's
external account, granted scopes or credential revision changes, or when it becomes reauthorization-required or
revoked. Future token refresh/replacement must increment `credential_revision` to activate this invariant.

Migration `20260904143000_add_search_console_verification.rb` creates `integration_connections`, adds nullable
Search Console binding/evidence columns to `domain_verifications`, composite tenant foreign keys, allowlists,
indexes and the invalidation trigger. Table creation is low risk; adding columns/index/FK/checks and validating
expanded failure-category checks take normal PostgreSQL DDL locks and scan existing verification rows. Deploy
before verification history is large. Rollback requires no retained Search Console challenges or new failure
categories because the foreign key and columns are removed and the earlier category allowlist is restored.
