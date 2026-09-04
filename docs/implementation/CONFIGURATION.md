# Environment, configuration and secrets contract

SearchOps loads and validates configuration during Rails initialization. Invalid
types fail every environment; staging and production additionally fail before
serving traffic when critical settings are absent or unsafe. Validation errors
contain setting names and constraints, never supplied values.

Foundational decisions and their current implementation status are listed in
the [ADR index](../adr/README.md).

## Sources and precedence

Public settings use this highest-to-lowest precedence:

1. runtime environment variable;
2. the active environment in `config/searchops.yml`;
3. `shared` in `config/searchops.yml`;
4. the schema default in `config/searchops/configuration.rb`.

Secrets use runtime environment variables first and environment-aware Rails
credentials second. They are rejected if placed in `config/searchops.yml` and
must never be given defaults. `.env.example` lists names and safe local public
values only; the application does not load dotenv files.

Use `Rails.application.config.x.searchops.fetch(:application_origin)` for public
values and `.secret(:billing_api_key)` for a secret. `#to_h` and `#inspect`
replace every present secret with `[FILTERED]`.

Rails credentials paths mirror their purpose, for example:

```yaml
secret_key_base: generated-value
database:
  password: injected-value
active_record_encryption:
  primary_keys:
    - newest-key
    - previous-key
  deterministic_key: generated-value
  key_derivation_salt: generated-value
billing:
  api_key: provider-value
  webhook_secret: provider-value
  webhook_previous_secret: temporary-previous-provider-value
```

The example shows structure only. Generate independent high-entropy values in a
secret-management workflow; do not copy literal documentation values.

## Configuration inventory

| Category | Public/runtime settings | Secrets and credentials |
|---|---|---|
| Application URLs | application name and exact application origin | Rails master key and secret key base |
| Database roles | process database role, four bounded pool sizes, process count, connection budget and SQL timeout bounds | PostgreSQL URLs for primary, queue, cache and cable, or one shared host/user/password credential set |
| Object storage | service, private bucket, region and optional endpoint origin | access key ID/secret when workload identity is unavailable |
| OAuth providers | enable flags, client IDs, bounded HTTP timeouts/response size, safe discovery/JWKS retries, JWKS TTL/key count, OIDC clock skew/token lifetime, transaction lifetime/retention, start/callback/session/account-security windows and per-IP/session caps | client secrets; callback tokens are transient and later persistent integration tokens use database encryption |
| Billing | provider (`disabled`, development/test-only `fake`, or `lemon_squeezy`), store ID, bounded HTTP open/read/write timeouts and response cap | API key and webhook verification secret |
| Encryption | active key version identifier | primary key ring, deterministic key and derivation salt |
| Crawler limits | URL, byte, redirect, concurrency and connect/read duration bounds | none |
| Browser limits | wall-time, memory, request-count and concurrency bounds | none |
| Provider integrations | Search Console, PageSpeed and CrUX enable flags | Google API key; user/provider tokens encrypted at rest |
| Email | delivery method, sender, SMTP host/port/user | SMTP password |
| Slack | enable flag and client ID | client and signing secrets; installations encrypted at rest |
| Observability | log level, tracing flag and collector origin | optional collector authentication token |
| Deployment metadata | release SHA, build timestamp and process role | registry/deployment credentials remain outside Rails |

Booleans accept only `true/false`, `yes/no`, `on/off`, or `1/0`. Durations require
an explicit `ms`, `s`, `m`, or `h` suffix and are returned as bounded seconds.
Integers are parsed strictly and range checked. Origins accept only HTTP(S), no
userinfo, path, query or fragment; staging/production require HTTPS and reject
local, private and loopback hosts. Enum values are allowlisted.

Production and staging require an application origin, release SHA, Rails secret
key base, Active Record encryption keys, a database connection budget, database
credentials, and S3 bucket and region. Database credentials are either all four
PostgreSQL role URLs (`DATABASE_URL`, `QUEUE_DATABASE_URL`,
`CACHE_DATABASE_URL`, and `CABLE_DATABASE_URL`) or the shared host, username,
and password settings documented in [Database topology](DATABASES.md). A partial
URL set fails initialization. Enabled OAuth, billing, SMTP and Slack
integrations add their own fail-fast requirements. Workload identity is
preferred for object storage, so static storage access keys are not mandatory.

## Redaction contract

`Shared::Redaction` applies the same case-insensitive sensitive-name policy to
Rails parameters, request headers, URL query pairs and structured event hashes.
It covers passwords, OAuth codes/state/tokens and provider error detail fields, API and encryption keys,
Authorization/Cookie headers, webhook signatures, provider credentials and page
credentials/bodies. URL userinfo is removed. Invalid URLs become
`[FILTERED_URL]`; callers must log the sanitized return value, never the input.

Structured logging is allowlist-first. Redaction is defense in depth and does
not authorize storing raw request/page bodies in events.

## Key rotation and versioning

- Keep a non-secret `SEARCHOPS_ENCRYPTION_KEY_VERSION` alongside encrypted rows
  or rotation metadata. The primary-key ring is newest first; retain old keys
  only for a bounded migration window, rewrite records, verify decryptability,
  then remove retired keys.
- Deterministic encryption rotation requires an explicit Rails previous-scheme
  migration and uniqueness review. Never replace its key in place.
- Webhook/API signing uses versioned key IDs and overlapping current/previous
  verification keys. New signatures use only the current key; old keys have a
  documented retirement deadline no shorter than the replay/retry window.
- Rotation events record key IDs, owner and timestamps in audit data, never key
  material. Backups and restore drills must preserve the keys needed by retained
  ciphertext.
- A suspected disclosure triggers revocation/rotation, session or token cleanup,
  provider reconciliation and a security regression test.
