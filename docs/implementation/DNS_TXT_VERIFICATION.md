# DNS TXT verification

DNS proof uses the exact hostname `_searchops-verification.<environment-host>` and the exact
`searchops-verification=<43-character base64url value>` shown to an authorized member. The proof value is
derived from a random challenge UUID plus its immutable tenant, environment, method and origin binding; only
its SHA-256 digest is stored. A pending challenge is consumed atomically by the first successful observation,
so concurrent or later replay cannot create a second success.

`Verification::DnsResolver` sends one absolute TXT question for that hostname through Ruby's recursive DNS
client. It has an outer wall-clock timeout plus resolver timeout, accepts at most 32 answer records and 4 KiB
of relevant TXT/CNAME material, follows at most five CNAME links already present in that response, and allows
at most eight observed authority NS records. It never follows arbitrary DNS names with a second query and has
no mutable process-global security cache. The response question must equal the requested name, preventing a
cached response for another hostname from being accepted.

DNS TXT protocol chunks are concatenated without separators. Their bytes, case and whitespace are otherwise
preserved. The adapter uses exact digest comparison: prefixes, suffixes, case changes and surrounding
whitespace do not match. One exact token among otherwise unrelated TXT records is accepted and recorded only
as bounded counts/booleans; duplicate exact tokens or multiple records without a unique match are classified
as `dns_multiple_records`. Stored evidence never includes names, record values, proof tokens or unrelated DNS
answers.

Observed outcomes distinguish NXDOMAIN, an empty TXT answer, a recent propagation heuristic, timeout,
transient resolver failure, multiple records, malformed/question-mismatched responses, and response,
CNAME or delegation limits. “Propagation” is explanatory guidance during the first 15 minutes after issuance,
not a guarantee that the record will later appear. DNS control does not authorize crawler egress or establish
that any resolved IP address is public.

The hourly `Verification::DnsRecheckSweepJob` selects at most 200 verified DNS challenges whose successful
observation is seven days old. It enqueues only explicit organization and challenge UUIDs. The target job
reloads and locks that exact tenant-bound challenge, rechecks the active environment and exact origin, and
records an append-only attempt. Success renews the observation and 30-day expiry. Failure preserves the prior
`verified_at`, so freshness admission becomes stale naturally; another transient recheck is allowed only after
six hours. Both paths emit redacted audit and outbox events.

## Local fake DNS testing

Automated tests never use live DNS. `SEARCHOPS_DNS_VERIFICATION_ENABLED=false` in the test environment keeps
the request-layer registry unconfigured, while resolver tests inject a callable returning sanitized answer
records. To exercise a local fake resolver, inject the same query contract into `Verification::DnsResolver`:

```ruby
query = ->(name:, timeout:) {
  {
    question_name: name,
    answer_count: 1,
    delegation_count: 0,
    records: [ { type: "txt", name: name, strings: [ "searchops-verification=..." ] } ]
  }
}
resolver = Verification::DnsResolver.new(query: query, timeout: 1)
```

For an opt-in live development smoke test, enable `SEARCHOPS_DNS_VERIFICATION_ENABLED=true` and point a real
public DNS record at a disposable development domain. Never commit the proof value or production resolver
payload; remove the record after the smoke test.
