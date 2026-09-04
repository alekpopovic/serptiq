# SearchOps — Rails Production MVP Blueprint

> Working product codename. Perform trademark and domain clearance before public launch.

This package is an implementation blueprint for a multi-tenant SearchOps SaaS that combines technical web SEO, JavaScript-rendered auditing, Search Console and performance data, application-store discovery checks, deep-link validation, issue workflow, release regression gates, subscriptions, billing, organizations, projects, members, roles, permissions, plan entitlements, and usage quotas.

## Baseline stack

- Ruby 4.0.5
- Ruby on Rails 8.1.3.1
- PostgreSQL as the only application, queue, cache, and cable database technology
- Solid Queue, Solid Cache, and Solid Cable
- Hotwire, Turbo, Stimulus, ERB, Tailwind CSS
- Minitest and Rails system tests
- Chromium plus Ferrum for rendered scans
- Lighthouse CLI for lab performance analysis
- S3-compatible object storage for large scan artifacts
- Docker and Kamal for production deployment
- Lemon Squeezy as the first billing adapter, behind a provider-neutral interface
- Native application-owned sessions and provider adapters for Google OpenID Connect and GitHub OAuth
- No Devise, OmniAuth, Doorkeeper, Sidekiq, Redis, Elasticsearch, or Kubernetes in the MVP

The exact patch versions are a dated baseline from 2026-09-04 and are pinned in the repository and container image.

## Quick start

Read [`CODEX_START_HERE.md`](./CODEX_START_HERE.md), then run the tracker validation and execute prompt `000`.

## Application development setup

The application baseline is Ruby 4.0.5, Bundler 4.0.14, Rails 8.1.3.1, Node.js 24.20.0, and PostgreSQL. Install the pinned runtimes with your version manager, provide a local PostgreSQL connection through `DATABASE_URL` when the defaults do not apply, then run:

```bash
bundle _4.0.14_ install
bin/rails db:prepare
bin/dev
```

For an isolated local stack, Docker Compose builds `Dockerfile.dev` with Ruby
4.0.5, starts PostgreSQL and prepares all application databases:

```bash
docker compose up --build --wait db web
curl --fail http://127.0.0.1:3000/up
docker compose --profile test run --rm test
docker compose down
```

The database is not published to the host. Compose data persists in a named
volume until it is intentionally removed with `docker compose down --volumes`.
See [`docs/implementation/CONTAINERS.md`](./docs/implementation/CONTAINERS.md)
for lifecycle and verification commands.

Copy `.env.example` only as a list of supported variable names; provide real values through an ignored local file or a secret manager and never commit them. The typed settings, precedence, production requirements, redaction rules, and rotation process are documented in [`docs/implementation/CONFIGURATION.md`](./docs/implementation/CONFIGURATION.md).

PostgreSQL connection names, pool budgeting, clean setup, key policy and the
strict readiness query are documented in
[`docs/implementation/DATABASES.md`](./docs/implementation/DATABASES.md).

Queue routing, isolated worker roles, retries, recurring ownership and the
disposable Solid Cache/Cable contract are documented in
[`docs/implementation/SOLID_STACK.md`](./docs/implementation/SOLID_STACK.md).

Frontend layout, component, accessibility and progressive-enhancement rules
are documented in
[`docs/implementation/FRONTEND.md`](./docs/implementation/FRONTEND.md).

Run `bin/quality` for the repository's Ruby, ERB, JavaScript, data-file, asset,
architecture and dependency-security gates. Triage and temporary waiver rules
are documented in
[`docs/implementation/QUALITY.md`](./docs/implementation/QUALITY.md).

Fast, default, full, security and browser test commands and their deterministic
support contracts are documented in
[`docs/implementation/TESTING.md`](./docs/implementation/TESTING.md).

CI jobs, the required branch-protection check, immutable action policy and
local reproduction commands are documented in
[`docs/implementation/CI.md`](./docs/implementation/CI.md).

Stable public error codes, request/job correlation, structured event naming
and logging prohibitions are documented in
[`docs/implementation/OBSERVABILITY.md`](./docs/implementation/OBSERVABILITY.md).

One-time organization invitation issuance, verified-email acceptance, token/cookie handling,
rate limits, expiration, and operational behavior are documented in
[`docs/implementation/SECURE_INVITATIONS.md`](./docs/implementation/SECURE_INVITATIONS.md).

The 57-key permission registry, eight immutable system-role templates, guarded idempotent
catalog sync, checksums, and development matrix report are documented in
[`docs/implementation/AUTHORIZATION_CATALOG.md`](./docs/implementation/AUTHORIZATION_CATALOG.md).

Load-balancer liveness/readiness behavior, safe release provenance and private
worker heartbeat inspection are documented in
[`docs/implementation/HEALTH_ENDPOINTS.md`](./docs/implementation/HEALTH_ENDPOINTS.md).

The initial Rails scaffold was generated outside the repository and merged without overwriting the blueprint:

```bash
mise exec ruby@4.0.5 -- rails _8.1.3.1_ new \
  /tmp/searchops-rails-001.P9eESQ \
  --name searchops \
  --database=postgresql \
  --css=tailwind \
  --javascript=importmap \
  --skip-git \
  --skip-bundle
```

The application runtime was subsequently upgraded and verified on Ruby 4.0.5 while retaining Rails 8.1.3.1. Later prompts refine database topology, CI, security tooling, and operational configuration.

Architecture decisions and their implementation status are indexed in
[`docs/adr/README.md`](./docs/adr/README.md). New durable decisions start from
[`docs/adr/ADR_TEMPLATE.md`](./docs/adr/ADR_TEMPLATE.md); module dependency rules
remain in [`docs/implementation/MODULE_BOUNDARIES.md`](./docs/implementation/MODULE_BOUNDARIES.md).

## Package map

```text
CODEX_START_HERE.md
PACKAGE_CONTENTS.md
AGENTS.md
README.md
README_SR.md
docs/
  00_EXECUTIVE_SUMMARY.md
  01_PRD_V1.md
  02_ARCHITECTURE.md
  03_ERD.md
  04_RBAC_PERMISSION_MATRIX.md
  05_PLAN_ENTITLEMENT_MATRIX.md
  06_SEO_RULE_CATALOG.md
  07_SECURITY_AND_THREAT_MODEL.md
  08_INTEGRATIONS_AND_API.md
  09_TEST_STRATEGY.md
  10_DEPLOYMENT_AND_OPERATIONS.md
  11_ROADMAP_AND_DEFINITION_OF_DONE.md
  12_SOURCE_REFERENCES.md
  adr/
config_blueprints/
prompts/
tracking/
schemas/
```

## How to use this package

1. Create a new empty Git repository named `searchops`.
2. Copy this package into the repository root.
3. Open the repository in Codex.
4. Give Codex the complete contents of `prompts/000_repository_reconnaissance.md`.
5. Execute prompts in numeric order. Do not batch unrelated prompts.
6. At the beginning and end of every prompt, use the tracker commands described in `tracking/README.md`.
7. Review every diff, test result, migration, security-sensitive change, and external integration before continuing.

Validate the package and tracker before starting:

```bash
ruby tracking/scripts/validate_blueprint.rb
ruby tracking/scripts/test_prompt_tracker.rb
ruby tracking/scripts/prompt_tracker.rb validate
```

Check the next prompt:

```bash
ruby tracking/scripts/prompt_tracker.rb next
```

Start a prompt:

```bash
ruby tracking/scripts/prompt_tracker.rb start 000
```

Complete a prompt:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 000 \
  --summary "Repository baseline recorded" \
  --tests "Not applicable"
```

Block a prompt honestly:

```bash
ruby tracking/scripts/prompt_tracker.rb block 000 \
  --reason "Required toolchain is unavailable"
```

## Execution policy

A prompt is complete only when:

- its scoped implementation exists;
- migrations and schema changes are reviewed;
- required automated tests pass;
- lint and security checks relevant to the change pass;
- documentation is updated;
- no unrelated changes are left in the working tree;
- the tracker contains a factual summary and actual test commands/results.

Never mark a prompt complete merely because code was generated. Never hide failing tests, skipped checks, unresolved security issues, or assumptions.

## Architecture constraint

This project begins as a modular Rails monolith. Separate process roles may scale independently, but they deploy the same application image and share one product release. A service may be extracted only after measured load, isolation, deployment, or ownership requirements justify it.

## Product boundary

The MVP is not a backlink index, global keyword database, bulk AI-content generator, or guaranteed-ranking product. Its core promise is:

> Detect search-visibility problems, prioritize them with evidence, assign ownership, verify fixes, and prevent regressions across web and mobile product surfaces.


## Validated package contents

- 120 separate numbered prompts plus a combined prompt book
- 57 permissions and 8 immutable system roles
- 5 initial plan tiers with 47 entitlement keys each
- 96 initial SEO, performance, AI-crawler, ASO, and deep-link rules
- 10 architecture decision records
- 4 JSON schemas
- an executable Ruby tracker and isolated tracker test suite
