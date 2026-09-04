# Test execution and support

SearchOps uses Minitest, real PostgreSQL and Rails system tests. The default
suite never contacts identity, billing, analytics or other providers. Use
synthetic fixtures and `TestSupport::ProviderFake`; an unscripted provider
operation raises immediately.

## Commands

Use the four configured PostgreSQL databases described in `DATABASES.md`.
From a prepared environment:

```bash
# Fast domain/model/policy/service feedback
bin/rails test test/domain test/models test/policies test/services

# Default non-browser suite
bin/rails test

# Browser journeys
bin/rails test:system

# Full Rails suite, including system tests
bin/rails test:all

# Security and provider contracts
bin/rails test test/security test/adapters/contracts

# Lint, static analysis, assets and dependency audits
bin/quality
```

Do not add automatic retries around flaky tests. Reproduce a reported order by
copying the printed seed exactly:

```bash
bin/rails test --seed 4242
bin/rails test test/security/malicious_http_fixture_test.rb --seed 4242
```

Rails prints `Run options: --seed ...`; two runs with the same code, database
state and seed must keep the same order. Tests that depend on time use
`at_fixed_time`; stable fixture identifiers use `deterministic_uuid`.
The default uses one process for stable local feedback. Opt into Rails-managed
parallel test databases explicitly with `PARALLEL_WORKERS=4 bin/rails test`.

## Test tree and shared contracts

The tree follows `docs/09_TEST_STRATEGY.md`: domain, model/database, policy,
service, request/controller, job, adapter contract/provider, system, security
and performance concerns have distinct homes. Rails-conventional directories
remain valid when they communicate ownership more clearly.

`test/support` is loaded by `test/test_helper.rb`. Tenant-owned operations use
the shared isolation assertions with an authorized tenant and an actual foreign
tenant/record ID. Block-scoped `with_current_tenant` always resets context.
Audit, usage and permission decisions use explicit observable protocols instead
of coupling tests to future persistence classes.

The malicious HTTP fixture is deliberately test-only and loopback-only. It can
emit metadata redirects, redirect loops, malformed content and a bounded large
body. Crawler safety tests must assert that prohibited targets receive zero
requests; they must never weaken production address policy just to reach the
fixture.

## System-test artifacts

Headless Chrome runs at 1400×1000 with browser-console logging enabled. Rails
captures PNG and HTML plus a console log under
`tmp/system-test-artifacts/` only when a system test fails. The entire `tmp`
tree is ignored by Git. Successful tests do not create artifacts. CI uploads
that directory only on failure and should apply a short retention period.

Before sharing an artifact, confirm it contains only synthetic test data. Never
put credentials or copied production payloads in a system test.
