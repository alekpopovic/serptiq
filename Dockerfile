# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t searchops .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name searchops searchops

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=4.0.5
FROM docker.io/library/ruby:$RUBY_VERSION-slim@sha256:42ad5227a4b2758f32563b34b5967e1055e75c80243eef04e6d2572887d1dec4 AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips postgresql-client && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment variables and enable jemalloc for reduced memory usage and latency.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libvips libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY vendor/* ./vendor/
COPY Gemfile Gemfile.lock ./

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
    bundle exec bootsnap precompile -j 1 --gemfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times.
# -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# These values only satisfy fail-closed boot validation while assets compile.
# They are non-provider, non-production placeholders and are not runtime defaults.
RUN SEARCHOPS_APPLICATION_ORIGIN=https://build.searchops.example \
    SEARCHOPS_RELEASE_SHA=asset-build \
    SEARCHOPS_DATABASE_CONNECTION_BUDGET=25 \
    SEARCHOPS_OBJECT_STORAGE_BUCKET=searchops-build-placeholder \
    SEARCHOPS_OBJECT_STORAGE_REGION=us-east-1 \
    DATABASE_URL=postgresql://build@db.invalid/searchops_build \
    QUEUE_DATABASE_URL=postgresql://build@db.invalid/searchops_build_queue \
    CACHE_DATABASE_URL=postgresql://build@db.invalid/searchops_build_cache \
    CABLE_DATABASE_URL=postgresql://build@db.invalid/searchops_build_cable \
    SECRET_KEY_BASE=ci-build-only-secret-key-base-not-for-runtime \
    ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEYS=ci-build-only-primary-key \
    ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=ci-build-only-deterministic-key \
    ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=ci-build-only-derivation-salt \
    ./bin/rails assets:precompile

# Shared application runtime. The default final image below intentionally has
# no browser; only the explicit `render` target installs Chromium.
FROM base AS app_runtime

ARG SEARCHOPS_BUILD_SHA=unknown
ARG SEARCHOPS_BUILD_TIMESTAMP=unknown
LABEL org.opencontainers.image.revision="$SEARCHOPS_BUILD_SHA" \
      org.opencontainers.image.created="$SEARCHOPS_BUILD_TIMESTAMP" \
      org.opencontainers.image.source="https://github.com/alekpopovic/searchops"

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

# Copy built artifacts: gems, application
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]

FROM app_runtime AS render

USER root
ARG CHROMIUM_PACKAGE_VERSION=152.0.7977.75-1~deb13u1
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y chromium="$CHROMIUM_PACKAGE_VERSION" chromium-sandbox="$CHROMIUM_PACKAGE_VERSION" && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives
LABEL io.searchops.chromium.package-version="$CHROMIUM_PACKAGE_VERSION" \
      io.searchops.ferrum.version="0.18.0" \
      io.searchops.runtime-role="worker_render"
USER 1000:1000
CMD ["./bin/jobs"]

FROM app_runtime AS final
