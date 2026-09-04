# Continuous integration

The `CI` GitHub Actions workflow is the merge gate for the application. It
uses read-only repository permissions, immutable action commits, a pinned
PostgreSQL service image and a digest-pinned production Ruby base image. Pull
requests and pushes to `main` run the same checks; maintainers can also start
the workflow manually.

## Jobs and local equivalents

Run commands from the repository root with Ruby 3.4.10, Node.js 24.20.0 and
PostgreSQL 17 available. The database-backed commands use the four test URLs
documented in [DATABASES.md](./DATABASES.md).

| CI job | Responsibility | Local equivalent |
| --- | --- | --- |
| `Tracker contracts` | Prompt state, tracker mutation tests and ADR index | `ruby tracking/scripts/prompt_tracker.rb validate`, `ruby tracking/scripts/test_prompt_tracker.rb`, `ruby script/check_adr_index` |
| `Quality and static analysis` | Ruby/ERB/JS/data/workflow lint, architecture, assets and dependency scans | `bin/quality` |
| `Rails tests` | Default non-browser Rails suite on PostgreSQL | `bin/rails db:prepare && bin/rails test` |
| `Security and provider contracts` | Fresh advisory data, static analysis, authentication and tenant-isolation regressions, consistency checks, hostile-input and adapter contracts | `bin/bundler-audit check --update`, `bin/importmap audit`, `bin/brakeman --quiet --config-file config/brakeman.yml`, `bin/authentication-security`, `bin/tenancy-security`, then `bin/rails test test/security/malicious_http_fixture_test.rb test/adapters/contracts` |
| `Browser system tests` | Critical browser flows and accessibility assertions | `bin/rails db:prepare && bin/rails test:system` |
| `Production image boot` | Production image build, schema preparation, non-root runtime and `/up`, `/ready`, `/version` probes | `script/ci_container_smoke` after creating the four smoke databases |
| `Required CI` | Fails unless every job above succeeded | Reproduce and pass every preceding row |

For a local image smoke test, create `searchops_container_ci` plus its
`_queue`, `_cache`, and `_cable` databases. Override
`SEARCHOPS_CI_DATABASE_HOST`, `SEARCHOPS_CI_DATABASE_PORT`,
`SEARCHOPS_CI_DATABASE_PASSWORD`, `SEARCHOPS_CI_DATABASE_PREFIX`,
`SEARCHOPS_CI_HTTP_PORT`, `SEARCHOPS_CI_IMAGE`, or
`SEARCHOPS_CI_DOCKER_NETWORK` when local defaults differ. The optional network
lets the smoke container address a PostgreSQL container by name.
The password, if used, must be URL-safe. The script builds the production
image, lets the entrypoint prepare schemas, verifies the process UID is not
root, probes `/up`, `/ready` and `/version`, and removes its temporary
container.

## Branch protection

Protect `main` in repository settings and require the `CI / Required CI`
status check. Also require the branch to be up to date, at least one approving
review, resolved conversations, and no administrator bypass for ordinary
merges. Only the aggregate check needs to be selected because it depends on
all executable CI jobs.

Superseded runs are canceled per workflow and Git ref to reduce branch noise.
The cancellation expression explicitly excludes the repository's default
branch, so an active protected-branch run is never canceled automatically.
This workflow performs no deployment and runs no migration against production.

## Supply-chain and credential policy

- External actions use full 40-character commit SHAs with an adjacent exact
  release comment. PostgreSQL uses an image digest. Dependabot proposes weekly
  action and Bundler updates; reviewers must verify the upstream release before
  accepting a new SHA.
- `ruby/setup-ruby` owns the Bundler cache, whose key includes the checked-in
  `Gemfile.lock`. No secret, generated asset tree, test artifact or Docker image
  is cached. Node setup is pinned but has no package cache because this project
  has no Node dependency lockfile.
- The workflow grants only `contents: read`; checkout persistence is disabled.
  It injects no GitHub repository secret and contains no provider credential.
  Container boot uses conspicuously synthetic application values and a
  disposable CI database password.
- Future cloud access must use short-lived, scoped OIDC federation and a
  separately reviewed deployment workflow, never long-lived cloud access keys
  in this CI workflow.

`script/validate_ci_workflow` enforces the immutable pins, read-only token,
bounded failure artifacts, digest-pinned PostgreSQL services, complete job set
and protected-branch concurrency rule. Browser and container diagnostics are
uploaded only after failure and retained for three days.
