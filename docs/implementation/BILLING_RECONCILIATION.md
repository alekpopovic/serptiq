# Billing Reconciliation and Support Operations

Prompt 049 adds a bounded comparison loop between provider subscription snapshots and the canonical local
subscription. It is a recovery mechanism, not a second billing state machine. The provider remains
authoritative for payment, invoice and tax records; application access continues to use only validated local
state.

## Reconciliation contract

`Billing::ReconciliationSweepJob` runs every six hours on the isolated `billing` queue. A sweep selects at
most 100 provider-backed subscriptions that are current or ended in the previous 30 days. The requester takes
a PostgreSQL advisory transaction lock for each provider/environment, permits at most 100 requests per hour,
permits one request per subscription per 15 minutes, and relies on a partial unique index to allow only one
queued/running/retryable run per subscription.

Workers receive only the reconciliation UUID, reload the exact `(organization_id, subscription_id)` pair and
fetch through the configured adapter. Provider, environment, customer, subscription and active plan mapping
must all match exactly. The retained snapshot is an 8 KiB bounded allowlist with a SHA-256 subscription
reference digest; raw IDs, payloads, credentials, invoices and personal data are not stored.

| Classification | Meaning | Automated action |
|---|---|---|
| `matched` | all compared canonical fields agree | update observation freshness without changing subscription revision |
| `repaired` | provider observation is newer and the explicit transition is allowed | apply through `ProjectProviderEvent`, including entitlement, audit and outbox work |
| `ambiguous` | mapping is absent, local evidence is newer, or transition is unsafe | no canonical mutation; operator investigation |
| `missing` | provider returned an exact not-found result | no canonical mutation; verify provider portal and tenant mapping |
| `retryable` | transient timeout, rate limit or outage | retry after provider delay or 5m/30m/2h/6h backoff |
| `failed` | permanent provider/projection failure or fifth failed attempt | no canonical mutation; operator investigation |

A newer `past_due` self-observation preserves the original seven-day grace deadline; periodic reconciliation
cannot extend delinquent access. Stale or equal-time ambiguous evidence is never used to overwrite local state.

## Support access

`GET /dashboard/admin/billing` is a platform support surface, not an organization-owner privilege.
`billing_support.read` reveals only sanitized webhook summaries, mapping status, reconciliation classifications,
consistency counts and metrics. `billing_support.manage` additionally reveals replay/reconcile controls. Both
grants are explicit, revocable user grants; an organization role cannot imply them.

Replay and targeted reconciliation are CSRF-protected and require an active session authenticated within the
recent-authentication window. Replay also requires exact text `REPLAY <event UUID>`. Targeted reconciliation
accepts an exact tenant/subscription pair and revalidates the relationship in the domain boundary. Each request
and outcome writes bounded audit evidence with the support actor where applicable. There is no direct SQL state
editor.

## Alerts and first response

Run `bin/rails billing:operations:metrics`. The same four structured events are emitted by the support read
model:

- `billing.webhook_lag`: warn when the oldest pending/retryable event is at least five minutes old;
- `billing.dead_letters`: warn for any dead letter;
- `billing.projection_failures`: warn when an actionable/dead event has at least three attempts;
- `billing.reconciliation_drift`: warn for any ambiguous, missing or failed reconciliation.

For a page:

1. declare provider/environment and incident time range without copying raw identifiers into chat or logs;
2. check queue depth and worker health, then run `bin/rails billing:operations:metrics`;
3. run `bin/rails billing:consistency:check`; it is read-only and exits nonzero on unexplained drift;
4. inspect the provider portal using the authorized support workflow and compare its update time with the
   sanitized local evidence;
5. if a mapping is missing or ambiguous, repair governed mapping/configuration first—never guess tenant or
   plan identity;
6. replay only a verified dead/retryable webhook or request one exact targeted reconciliation;
7. confirm the new reconciliation classification, entitlement revision and outbox/queue health;
8. preserve audit evidence and escalate as SEV-1 for cross-tenant evidence or unrecoverable corruption, SEV-2
   for a broad backlog, otherwise according to customer impact.

During a provider outage, do not bulk replay: leave transient runs retryable, honor provider rate limits and
watch the bounded backoff. After recovery, allow the scheduled sweep to converge, then target only remaining
drift. A missing object is evidence, not permission to expire access automatically.

## Consistency and deployment

`billing:consistency:check` reports duplicate customer/subscription mappings, subscriptions without a plan,
provider subscriptions without a customer mapping, missing active entitlement contexts, revision mismatch and
projection-field mismatch. Unique indexes and foreign keys normally make several categories zero; retaining
the queries provides detection after restores/imports or constraint changes.

Migration `20260904123000` creates support grants and reconciliation runs with UUID keys, tenant/subscription
composite foreign keys, lifecycle checks, bounded JSON and operational indexes. It creates new tables only, so
there is no row backfill. DDL still takes catalog locks; deploy before enabling the recurring schedule and use
the normal migration lock budget. Rollback removes only reconciliation history and support grants, so export
required incident evidence before a downgrade.
