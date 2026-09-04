# Identity data model

Prompt 015 completes the durable Identity records that provider adapters use.
All four tables use UUID primary keys and PostgreSQL `timestamptz` timestamps.
`users.primary_email` and `identities.email` use `citext` in addition to
application normalization; email remains contact/observational metadata and is
never the authority for account resolution.

## Users and provider identities

`Identity::User` owns server sessions and `Identity::ProviderIdentity` rows.
A provider identity is selected only by the globally unique pair
`(provider, provider_subject)`. The subject is the provider's stable identifier;
GitHub login names and email addresses are not lookup keys. Two distinct
subjects may therefore report the same normalized email and remain attached to
different users. Automatic email-based merging is prohibited.

The provider allowlist is `google` and `github` in both model and database
constraints. An identity may omit email when the provider supplies no usable
address, but a `true` provider verification assertion requires an address.
Profile JSON is an 8 KiB bounded object and accepts only `name`, `login`,
`avatar_url`, and `locale` text observations. It must never hold tokens or a raw
provider response. The application escapes these untrusted values if they are
later rendered.

Foreign keys use restrictive deletion. A user, identity, or session cannot be
silently removed through an association cascade, and provider subjects are not
reassigned as a side effect of email changes.

## One-time OAuth transactions

`Identity::OauthTransaction` stores:

- keyed SHA-256 digests of state, nonce, and the PKCE verifier;
- an AES-256-GCM authenticated ciphertext of the PKCE verifier, because the
  callback must recover it for the authorization-code exchange;
- an allowlisted local return path, expiry, consumption time, and attempt
  count/time metadata.

Raw state and nonce are never persisted. The verifier ciphertext uses a
purpose-specific key derived from the application secret, and its stored digest
is checked after decryption. No access token, refresh token, authorization code,
ID token, or provider credential column exists in these identity tables.

State lookup and consumption run through `Identity::Public`. Consumption takes
a PostgreSQL row lock, records every found attempt, and sets `consumed_at` once.
A concurrent or later replay receives the stable
`oauth_transaction_consumed` error. Expired attempts are recorded but never
consumed. Lifetimes are database-bounded to 15 minutes. Google transactions
require a nonce; GitHub transactions may omit it. Rotating the application
secret intentionally invalidates any outstanding short-lived transaction; an
operator should either drain that window or accept that users must restart
sign-in.

## Deletion and anonymization contract

Account deletion is an explicit orchestration operation, not an Active Record
callback. The later privacy workflow must, in one reviewed sequence:

1. mark the user deleted and prevent authentication;
2. revoke every live session and provider identity;
3. clear `primary_email`, display name, avatar URL, identity email, and profile;
4. retain or transform the stable provider subject only for the documented
   security/legal tombstone period, then remove it according to retention;
5. preserve required append-only audit evidence in redacted/pseudonymous form;
6. reconcile memberships and tenant-owned data under their own ownership rules.

Until that workflow exists, callers must not use `destroy` as an account-
deletion shortcut. Soft-deleted users are denied new and existing sessions by
the session boundary.

## Migration and operations

The migration enables PostgreSQL `citext`, converts the pre-provider
`users.primary_email` column, creates `identities` and `oauth_transactions`, and
adds foreign keys, unique/partial indexes, format checks, JSON bounds, and
one-time metadata checks. On the pre-launch empty/small identity tables this is
a bounded migration. Enabling an extension and changing the email type require
database privileges and an access-exclusive table lock; a populated production
deployment must measure that conversion and schedule it before release.

Rollback removes the two new tables, returns the user email to `varchar`, and
removes `citext`. It is safe only before provider identities/OAuth attempts are
real; after launch, use a reviewed forward migration.
