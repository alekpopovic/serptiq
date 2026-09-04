# Authentication abuse controls and regression gate

Prompt 023 reviewed the native Google OIDC and GitHub OAuth implementation
against ADR 0003 and the protocol sources indexed in `docs/12_SOURCE_REFERENCES.md`.
The application keeps one-time HMAC-digested state, a Google nonce, S256 PKCE,
an exact configured callback URI and a local-path-only return destination.
Callbacks consume state once before exchange, Google validates the signed ID
token and required claims, GitHub uses the stable numeric subject, and neither
provider email nor login name can silently merge accounts. Successful sign-in
issues a fresh application-owned token; identity changes rotate the current
session.

## PostgreSQL rate-limit boundary

`Identity::AuthenticationRateLimiter` stores fixed-window counters in
`authentication_rate_limit_buckets`. It uses an atomic PostgreSQL upsert, so
concurrent processes share one decision boundary. The stored key is an HMAC of
the policy scope plus an already canonical IP digest or opaque local session
ID. Raw addresses, cookies, tokens, provider subjects and email addresses are
never rate-limit keys or table values.

Default policies are:

| Scope | Limit | Window | Key |
| --- | ---: | ---: | --- |
| OAuth initiation | 20 | 5 minutes | canonical-IP digest |
| OAuth link initiation | 10 | 5 minutes | local session |
| Callback failures | 10 | 5 minutes | canonical-IP digest |
| Session management | 30 | 5 minutes | local session |
| Account security actions | 20 | 5 minutes | local session |

OAuth outstanding-attempt caps remain five per address and two per link
session. Admission counters include accepted initiation/session/account
requests; attempts rejected by the outstanding OAuth cap do not consume the
fixed-window initiation counter because the enclosing transaction rolls back.
Callback counters record failures only. A legitimate callback success neither
increments nor clears prior failures, so one successful request cannot erase
abuse history. Every window expires independently; no counter creates a
permanent account lockout.

Rate denials always use the generic `rate_limited` public code and message, plus
an integer `Retry-After` bounded to one day. No response varies by provider
account existence. `auth.rate_limit_decision` records only the allowlisted
scope/outcome, while `auth.failure_categorized` records one of seven bounded
failure categories. Neither event contains the key or request secrets.

`Identity::AuthenticationRateLimitCleanupJob` runs hourly at minute 42 on the
maintenance queue and deletes at most 10,000 expired rows in ordered batches.
Expiry is enforced by the request-time window calculation even if cleanup is
delayed.

## Required regression command

Run the authentication security gate with real PostgreSQL:

```bash
bin/rails db:prepare
bin/authentication-security
```

The command covers state/nonce/PKCE tampering, replay, callback and return
redirect restrictions, session fixation, collision policy, redaction, HTTP
retry metadata and concurrent rate-limit atomicity. The CI security job runs it
before the remaining hostile-input and provider adapter contracts.

When it fails, first retain the random seed and failing test name, then inspect
the sanitized `auth.rate_limit_decision`, `auth.failure_categorized` and
`auth.oauth_callback_rejected` events by Request ID. Check the affected bucket
only by scope, window and aggregate count; never copy a raw callback query,
cookie, provider response or rate-limit key into an issue or CI artifact. Run
the named test alone, then rerun `bin/authentication-security` to confirm the
fix did not weaken a neighboring protocol control.

The migration creates a new internal bigint-keyed table and indexes without
rewriting an existing table. Rollback drops only ephemeral counters. Deploying
it before application code is safe; deploying application code before the
migration is not.
