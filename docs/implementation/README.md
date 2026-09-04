# Implementation Evidence

Prompts create factual implementation reports in this directory when a document is larger than the structured tracker result.

Expected early files:

- `000_BASELINE.md`
- `MODULE_BOUNDARIES.md`

Expected final file:

- `PRODUCTION_MVP_ACCEPTANCE.md`

Do not pre-populate these reports with fictional implementation or test results.

## Architecture governance

- [`../adr/README.md`](../adr/README.md) indexes accepted decisions, owners,
  review dates and implementation status.
- [`../adr/ADR_TEMPLATE.md`](../adr/ADR_TEMPLATE.md) is the required starting
  structure for a new durable decision.
- [`MODULE_BOUNDARIES.md`](./MODULE_BOUNDARIES.md) defines enforceable module
  ownership and dependencies.
- [`CONFIGURATION.md`](./CONFIGURATION.md) defines public/secret configuration,
  redaction and key rotation.
- [`DATABASES.md`](./DATABASES.md) defines PostgreSQL topology, capacity,
  identifiers, setup and readiness behavior.
- [`SOLID_STACK.md`](./SOLID_STACK.md) defines queue isolation, retries,
  recurring ownership, disposable cache/cable bounds and worker operations.
- [`FRONTEND.md`](./FRONTEND.md) defines server-rendered UI, accessibility,
  reusable component, Hotwire and future charting conventions.
- [`QUALITY.md`](./QUALITY.md) defines local lint/security gates and the
  time-bounded advisory waiver process.
- [`TESTING.md`](./TESTING.md) defines suite tiers, deterministic support,
  tenant/provider boundaries and failure artifacts.
- [`../../tracking/README.md`](../../tracking/README.md) defines prompt evidence,
  recovery and state integrity.
