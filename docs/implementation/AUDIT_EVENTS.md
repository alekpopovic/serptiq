# Append-only audit events

Prompt 035 introduces the durable `Auditing` boundary for security and administrative history. Tenant
mutations record the verified membership actor and organization, while account identity/session events use
a user actor and may have no organization. Every event has a fixed dotted action, target type and optional
UUID, result, bounded metadata, request/trace/job correlation and occurrence time.

Metadata is an internal allowlist, not a payload store. Email, IP, user-agent, secret, credential, token,
cookie, body and payload-shaped keys are filtered, and strings that resemble email addresses or user-agent
values are removed. Raw client addresses and user-agent values are prohibited; the schema accepts only
64-character keyed digests in the optional client fields.

Persisted events are read-only through the Active Record model. Foreign keys and actor-shape checks bind a
membership actor to the event organization, and bounded checks constrain action, result, metadata and
correlation fields. The table is new, so deployment does not rewrite an existing relation; rollback removes
the audit history and therefore requires an explicit retention decision before use in production.

Organization audit history requires `audit_log.read` at organization scope in both the controller and query
boundary. Filters are exact and allowlisted, results are ordered by occurrence time and UUID, and pages are
bounded to 50 records. The CSV route verifies `audit_log.export` but intentionally returns the standard
entitlement denial until the separate `audit.export` entitlement implementation exists.

Run `bin/tenancy-security` for the required Phase 03 isolation suite and both consistency reports. Operators
can run `bin/rails auditing:consistency:check` independently; any orphan or known cross-tenant actor/retained
tenant target causes a non-zero exit. Expired sessions are intentionally excluded because their audit IDs
outlive the session-cleanup retention window.
