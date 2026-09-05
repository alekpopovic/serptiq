# Structured observability and public errors

SearchOps emits allowlisted JSON operational events and exposes a separate,
stable public error contract. Operator context is useful for correlation but
must never become a second copy of customer payloads, provider credentials or
fetched page artifacts.

## Error taxonomy

Every expected domain rejection uses a `Shared::Errors` subclass. Controllers
return the catalog message and code, never the exception message.

| Category | Public code | HTTP | Meaning |
| --- | --- | ---: | --- |
| `validation` | `validation_failed` | 422 | Input failed a domain validation |
| `authentication` | `authentication_required` | 401 | A valid authenticated session is required |
| `authorization` | `authorization_denied` | 403 | The actor lacks permission for the scope |
| `entitlement` | `entitlement_required` | 403 | The organization lacks an enabled feature |
| `quota` | `quota_exceeded` | 429 | A reservation or usage limit is unavailable |
| `conflict` | `resource_conflict` | 409 | Resource state prevents the transition |
| `external_provider` | `external_provider_failed` | 502 | A provider could not complete the operation |
| `transient_infrastructure` | `service_temporarily_unavailable` | 503 | Retryable application infrastructure failure |
| `unsafe_destination` | `unsafe_destination` | 422 | Network destination policy rejected the target |
| `internal_fault` | `internal_error` | 500 | Unexpected or explicitly internal fault |

HTML and JSON responses carry the same code and message. JSON uses
`{"error":{"code":"...","message":"...","request_id":"..."}}`; every
mapped response also sets `X-SearchOps-Error-Code`. A `reason_code` may refine
operator decisions, but it must be an internal snake-case value and does not
replace the public code.

Unexpected faults and expected faults with a cause are reported through the
Rails error reporter with safe correlation and the public code. Structured
logs retain the exception and cause class names only. The public response and
JSON event never include exception messages, backtraces or provider response
bodies. Error-reporting access is an operator privilege and follows the
retention and access-audit policy from the security model.

## Correlation lifecycle

`Shared::Observability::RequestContext` runs after Rails request-ID assignment.
It accepts only bounded correlation characters, extracts a valid W3C trace ID
when present, attaches release/environment data and resets all state in an
`ensure` block. Invalid inbound IDs are replaced with a generated UUID.

`ApplicationJob` serializes only the originating trace ID. Its around hook
starts from an empty context, adds job/release/environment correlation, emits a
sanitized failure event and clears state even when execution raises. Job
arguments must still contain explicit tenant identifiers and the job must
re-authorize its records; correlation is not authorization.

Code that has already validated tenant ownership may call
`Context.attach_resources`. Organization IDs are emitted only as a keyed HMAC
prefix. Project and scan values must be application UUIDs. The context never
contains a membership, email address, raw token or customer-controlled label.

## Event contract

Event names are internal dotted identifiers such as
`http.request_failed`, `job.execution_failed` and
`crawler.destination_rejected`. They are at most 96 characters and are never
formed from a hostname, URL, provider response or customer value. Every event
contains:

- UTC `timestamp`, `severity`, `event_name` and integer `event_version`;
- `release` and `environment` when running inside a request or job;
- optional bounded `request_id`, `trace_id` or `job_id`;
- optional hashed organization ID and validated project/scan UUID;
- only allowlisted operation, outcome, timing, retry, provider and error
  fields, including a fixed low-cardinality pressure `scope_type` where needed.

Additive optional fields retain the current event version. Increment
`event_version` when a consumer-visible field is removed, renamed, changes
type, or its meaning changes. During a version transition, update dashboards
and alerts before removing the prior version.

The emitter rejects unknown attributes, invalid event names, negative timing
or retry values, invalid status codes, more than five cause classes and labels
outside its bounded low-cardinality format. Metrics must use a fixed internal
name and bounded enums; event IDs, tenant IDs, hostnames, paths, URLs and error
text are never metric labels.

Prompt 071 adds `crawler.fetch_pressure`, `crawler.emergency_control` and fixed
pressure snapshot metric events. They expose bounded outcomes, reason codes,
counts and one of `global`, `organization`, `scan` or `host`; host digests,
hostnames, URLs, permit tokens and tenant identifiers never become labels.

## Redaction and prohibited fields

Use the shared redactor before recording parameters, headers, query data or a
provider payload. It recursively removes OAuth codes/state/tokens, passwords,
cookies, authorization values, API keys, signing and billing secrets, email
addresses, raw request/response bodies, HTML, rendered DOM, HAR, Lighthouse
JSON and screenshots. URL logging removes userinfo/fragments and filters every
query value, including values whose key looks harmless.

The following are prohibited from structured events and ordinary logs:

- raw page, webhook, XML, JSON-LD or provider response bodies;
- access/refresh/ID tokens, OAuth codes/state, session cookies and API keys;
- signing, encryption, billing, database and object-storage credentials;
- full customer query strings, authorization headers and userinfo URLs;
- email addresses or other personal data;
- arbitrary exception messages/backtraces as structured labels;
- customer strings in event names, metric names or unbounded labels.

Large sanitized diagnostics belong in access-controlled object storage with a
bounded retention policy, not PostgreSQL or routine application logs.
