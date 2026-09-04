# Local containers

The repository pins Ruby 4.0.5 in the host toolchain, Bundler lock and both
Dockerfiles. The original `Dockerfile` remains the minimal production image.
The focused `Dockerfile.dev` includes every locked gem group and build tools
needed for local development and tests; both images use the same digest-pinned
official Ruby base.

## Start the application

From the repository root:

```bash
docker compose up --build --wait db web
curl --fail http://127.0.0.1:3000/up
```

Set `SEARCHOPS_WEB_PORT` before the command when port 3000 is already occupied.
The web container runs as UID/GID 1000 and its entrypoint prepares all four
development schemas before Puma starts. Compose bind-mounts the repository at
`/rails`, so local source changes are immediately visible to the development
server and test container.

PostgreSQL 17.10 is digest-pinned, accepts passwordless connections only on the
private Compose network and publishes no host port. The initialization script
creates distinct primary, queue, cache and cable databases for both development
and test. Application data persists in the `searchops_postgres` named volume.

## Test in the Ruby image

The test profile does not start during ordinary `up`. Run it explicitly:

```bash
docker compose --profile test run --rm test
docker compose --profile test run --rm test ruby --version
```

The test entrypoint applies all PostgreSQL schemas before executing the supplied
command. It never calls an external provider; default tests use fakes and
sanitized fixtures.

## Stop and reset

```bash
docker compose down
```

The command above preserves database data. Only when an intentional clean reset
is required, remove the named volume as well:

```bash
docker compose down --volumes
```

The Compose topology is a local development and verification convenience. It
does not weaken the production requirement for managed credentials, encrypted
connections, independently budgeted databases and deployment-time secret
injection.
