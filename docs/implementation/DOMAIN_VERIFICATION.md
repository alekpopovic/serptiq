# Domain verification

Prompt 053 implements auditable, expiring proof of control for an exact tenant-bound property environment.
`domain_verifications` stores immutable organization/project/property/environment/method/origin binding, a
digest of the high-entropy proof value, lifecycle timestamps, rate-limit counters and bounded safe evidence.
`domain_verification_attempts` is append-only and preserves each adapter outcome without response content.

Supported method keys are `dns_txt`, `html_file`, `meta_tag` and `search_console`. Their adapters share the
`verify(challenge:, expected_value:)` contract and return `Verification::AdapterResult`. DNS retains only match
and record count. HTML/meta retain only exact-origin match, status, byte count and match. Search Console retains
only the exact verified-property boolean. Production HTML/meta and Search Console clients are intentionally not
created by Prompt 053: HTML/meta clients must implement the crawler-safe exact-origin fetch contract, and Search Console
must use an authorized connected account. Disabled or not-yet-configured methods retain the safe
`provider_unavailable` fallback; DNS TXT is wired when `dns_verification_enabled` is true.

Issuance requires `properties.verify`, revokes an existing pending/verified challenge for that environment and
sets the primary property summary to pending. Attempts serialize sequence allocation, allow one attempt per 30
seconds and fail terminally after five mismatches. Success is idempotent, expires after 30 days and updates the
primary property summary. Explicit revocation is idempotent. A PostgreSQL trigger revokes pending/verified proof
when its environment origin changes, including callback-bypassing writes.

Freshness admission is workload-specific: standard work accepts proof up to 30 days old, high-volume work up
to seven days and render work up to 24 hours, always bounded by `expires_at` and exact current-origin equality.
Verification proves observed control at a point in time; it neither authorizes a crawl destination nor
guarantees the safety of a URL.

DNS TXT verification is implemented by Prompt 054 and documented in
[`DNS_TXT_VERIFICATION.md`](./DNS_TXT_VERIFICATION.md). It performs one bounded query for the exact challenge
hostname, preserves TXT chunk bytes while concatenating protocol chunks, and accepts only one exact token
match. Its periodic recheck is an ownership observation: a failure does not renew freshness and does not by
itself claim that control was lost.

Migration `20260904140000_create_domain_verifications.rb` creates both tables, composite foreign keys, partial
current-challenge uniqueness, checks, immutable-history triggers and the origin invalidator. It adds one unique
identity index to `property_environments`; on a production-sized table that index build takes a normal
PostgreSQL table lock and should be scheduled during the MVP deployment window. Rollback removes only
verification data and its added environment index.

Migration `20260904141000_expand_dns_verification_failures.rb` adds allowlisted DNS failure categories to
both verification tables. Adding and validating each check scans the corresponding table and briefly takes
the normal PostgreSQL DDL lock; deploy before verification history becomes large.
