# Billing webhook projection

Checked against Lemon Squeezy's official webhook request, event-type and Subscription-object documentation on
**2026-09-04**. `Billing::WebhookProjectionJob` receives only a durable event UUID. The processor locks that
record, decrypts and checksum-verifies the original body, applies parser version 1, and re-runs the provider
adapter's bounded payload/environment/catalog validation.

## Correlation and tenancy

The signed provider customer ID must resolve through exactly one immutable
`billing_customers(provider, environment, provider_customer_id)` mapping. Subscription variants must resolve
through one active store/product/variant mapping to an immutable plan version. No email, display name, URL or
untrusted metadata can select an organization.

When checkout custom data is present, all of `organization_id`, `plan_version_id`, `checkout_session_id` and
`correlation` are required. The HMAC is recalculated over the exact local checkout tenant, plan, session and
environment, and the session's customer mapping must match. Partial, cross-tenant or altered correlation is a
terminal dead letter. A missing customer, checkout or subscription mapping is retryable and cannot create a
guessed tenant.

## Ordering and canonical state

Subscription resource events normalize to the provider-neutral `SubscriptionSnapshot`. Projection locks both
mapping and canonical subscription rows. An older provider `updated_at` is recorded as `stale` and cannot
overwrite state. At an equal timestamp the deterministic restrictive order is:

```text
expired > past_due > paused > canceled > pending > active/trialing
```

This is a fail-closed tie-break only; a genuinely newer timestamp still wins, including resume and unpause.
The accepted snapshot updates plan presentation, canonical lifecycle/access, periods and bounded provider
facts. The subscription event reference is stored only as a digest.

Lemon Squeezy documents that `subscription_updated` accompanies lifecycle and payment changes. Consequently,
`order_created`, `order_refunded` and the four subscription-payment events are correlated, audited
observations; they never guess a subscription lifecycle from an Order or Subscription Invoice object.
Unsupported event names remain encrypted and finish as `ignored`. Unsupported local parser versions and
permanently invalid correlations become dead letters.

## Attempts, replay and side effects

The event transition and canonical update share one PostgreSQL transaction. Failed attempts roll back every
canonical/audit change, then persist a bounded category as `retryable` or `dead_letter`. Retryable failures use
bounded backoff metadata and at most five domain attempts. A controlled replay accepts only retryable/dead
letters plus the exact confirmation `REPLAY <event UUID>`, retains attempt history, records a system audit and
enqueues after commit.

`Entitlements::Public.bind_subscription` runs only when plan, status, access, period, cancellation or terminal
state actually changes. Merely advancing provider observation time does not invalidate access revisions.
Every applied/stale/observed tenant-correlated event creates a bounded audit record; operational telemetry has
only low-cardinality outcome/category labels.

## Migration and operations

`20260904101000_add_billing_webhook_projection_state.rb` adds parser/result/replay/retry and optional
tenant/subscription correlation columns to the ingress table, plus ordering evidence to subscriptions. It
replaces the ingress lifecycle check, adds tenant-safe composite foreign keys and adds small operational
indexes. Existing webhook rows receive parser version 1 and replay count 0. Existing subscriptions receive
precedence 0 and no event digest. These constant-default additions and index/constraint creation require brief
catalog locks; deploy before sustained webhook volume or phase the indexes on a mature table.

Alert on retry age, fifth-attempt dead letters, invalid checkout correlation, unknown parser versions and stale
event spikes. Replays are operator actions, not customer controls.

Sources:

- <https://docs.lemonsqueezy.com/help/webhooks/webhook-requests>
- <https://docs.lemonsqueezy.com/help/webhooks/event-types>
- <https://docs.lemonsqueezy.com/api/subscriptions/the-subscription-object>
