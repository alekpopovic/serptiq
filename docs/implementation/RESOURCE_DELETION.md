# Project and property retention deletion

Project and property deletion is a durable Administration workflow, never a synchronous controller cascade.
The browser first shows export and retention warnings and requires the exact project slug or property display
name. The domain boundary then rechecks `projects.delete`, active membership, the exact tenant/resource scope
and a recently authenticated native session.

## Lifecycle and hold

Archive and deletion request both make the resource authorization scope unavailable for ordinary child work,
set a cancellation cutoff and immediately prevent new scan admission. Jobs that began at or before the cutoff
can query the explicit Projects/Properties cancellation signal and stop cooperatively. A deletion request moves
the aggregate to `pending_deletion`, creates one exact-target workflow and schedules it after a 30-day hold.

During the hold the aggregate and current retained evidence remain read-only. Only permissions that already
allow archived-resource access can read it. An authorized user can cancel strictly before `hold_until`; the
aggregate then remains archived. Repeating the same request returns the existing active workflow and does not
create a second cascade. The hold duration is product policy, not a claim about universally applicable law.

## Ordered asynchronous workflow

`resource_deletion_workflows` owns the exact organization/project/property target, requester, hold, state,
lease, retry time and sanitized error category. Seven persisted stage rows enforce this order:

1. verify the cooperative cancellation signal;
2. detach/revoke resource integrations;
3. delete scan inputs, scans and findings;
4. delete report records;
5. delete the private object prefix and prove that no objects remain;
6. revoke API keys and webhook endpoints;
7. delete verification/onboarding/property/project aggregates.

Each stage has durable state, attempt count, timestamps and an optional bounded cursor. A worker claims a
five-minute lease under row lock. Completed stages are not replayed. Incomplete pagination and classified
object-store failures retain the current stage and retry time; the hourly sweep re-enqueues due, retryable and
expired-lease workflows in batches of at most 200. Object reconciliation must succeed before aggregate rows
can be removed.

The repository currently has resource-owned crawl policies, verification evidence, onboarding drafts,
properties and projects, and those are physically removed by their owning public APIs. Resource-scoped scan,
finding, report, API-key and webhook tables arrive in later prompts, so their ordered stages are deliberate
no-ops until those owners attach cleanup APIs. `EmptyObjectStore` is valid only while the application has no
private artifact persistence; Prompt 070 must replace the factory adapter when that storage is introduced.

## Database and retained evidence

PostgreSQL triggers reject direct deletion of projects, properties, crawl-policy history and verification
history. They allow it only inside a transaction carrying the exact workflow UUID while that same-tenant
workflow holds an unexpired lease in the required stage after its hold. Exact composite foreign keys bind a
pending resource and every tombstone to its workflow.

Final cleanup keeps append-only audit/outbox evidence and immutable minimized tombstones for Project,
Property, PropertyEnvironment, DomainVerification and CrawlPolicy identities. Tombstones contain stable UUIDs,
the resource hierarchy, workflow UUID and deletion time—not names, origins, credentials, payloads or object
keys. Audit consistency treats a same-tenant tombstone as the retained target identity after physical removal.
Billing, security-audit and other regulated history remains under its owning retention class.
Archived Authorization scope references and their assignments are also retained as inactive attribution
history; they grant no access and continue to satisfy assignment foreign keys after the aggregate is gone.

## Operations and policy review

Operators should alert on overdue holding workflows, repeated `retryable` state, expired running leases,
object-reconciliation failures, queue age and unusually growing tombstone counts. Retry only after confirming
the failing stage is idempotent. Do not manually set the workflow GUC or bypass deletion triggers.

Before production launch, privacy/legal owners must approve: hold duration; data readable during the hold;
retention periods for audit, billing and security history; export availability and expiry; backup/PITR erasure
expectations; processor/provider deletion duties; litigation or fraud holds; and customer-facing policy text.
Those decisions vary by jurisdiction and contract and are intentionally not encoded as universal legal advice.

Migration `20260904146000` adds three empty tables, five nullable lifecycle columns, indexes, checks, exact
foreign keys and trigger functions. It does not rewrite existing rows. Adding/replacing lifecycle checks and
foreign keys takes ordinary PostgreSQL catalog locks; deploy within the measured DDL lock budget. Rollback was
exercised on PostgreSQL, but removes all workflow/tombstone history and is safe only before production use.
