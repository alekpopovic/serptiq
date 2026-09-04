# Prompt 000 repository baseline

Captured on 2026-09-04 before application initialization. Items marked **Fact** were observed with the commands named below. Items marked **Assumption** or **Proposed** have not yet been established by implementation.

## Repository state

- **Fact:** This is an initialized Git repository on branch `main`, tracking `origin/main` at `git@github.com:alekpopovic/searchops.git`.
- **Fact:** Before Prompt 000 was started, `main` matched `origin/main` at commit `876371c4122ae263e9ff04500d6c21b78ebf50fe` and the working tree was clean.
- **Fact:** The initial commit contains 181 tracked files and is the only commit in the repository at this baseline.
- **Fact:** The tracked content is a SearchOps blueprint: documentation, 120 numbered prompts, configuration blueprints, four JSON schemas, and tracker scripts/state.
- **Fact:** Starting the tracker changed only its expected mutable state and execution-log files and created the zero-byte runtime lock `tracking/.state.lock`.
- **Fact:** Prompt 000 added a root `.gitignore` entry for the runtime lock. Tracker state and execution logs remain tracked.

Commands used:

```text
git status --short --branch
git status --porcelain=v2 --branch
git branch --show-current
git remote -v
git log -5 --oneline --decorate
git ls-files
git ls-files --others --exclude-standard
```

## Application and repository inventory

- **Fact:** No Rails application exists yet: there are no `app/`, `config/`, `db/`, `test/`, or `spec/` trees.
- **Fact:** There is no `Gemfile`, gemspec, JavaScript package manifest/lockfile, `.ruby-version`, `.tool-versions`, or `mise.toml`.
- **Fact:** There is no database configuration, schema, structure dump, or migration.
- **Fact:** There is no `.github/` CI configuration.
- **Fact:** There is no `Dockerfile`, Compose file, or Kamal configuration.
- **Fact:** No pre-existing untracked files were present before the tracker created its runtime lock.
- **Fact:** No repository file outside `.git/` is larger than 1 MiB. The largest tracked source artifact is the combined prompt book, below 1 MiB.

The inventory used `rg --files`, targeted manifest globs, directory enumeration, `find` size checks, and Git's tracked/untracked file lists. Absence statements apply to this captured working tree only.

## Local toolchain

| Tool | Observed result | Readiness note |
|---|---|---|
| Operating system | Ubuntu 26.04.1 LTS, Linux 7.0.0-30-generic, x86_64 | **Fact:** local execution platform |
| Ruby | 4.0.5 | **Fact:** differs from the blueprint's Ruby 3.4.10 candidate; Prompt 001 must resolve and pin compatibility |
| Bundler | 4.0.14 | **Fact:** executable works, but the configured home is not writable in this sandbox and Bundler falls back to a temporary directory |
| Rails | 8.1.3.1 | **Fact:** globally available; no application bundle exists yet |
| PostgreSQL client | unavailable (`psql` not found) | **Fact:** missing prerequisite for local database diagnostics |
| Node.js | v26.4.0 | **Fact:** globally available but not yet project-pinned |
| npm | 11.17.0 | **Fact:** globally available but not yet project-pinned |
| Chromium | Snap launcher present, version command cannot create its sandbox runtime directories | **Fact:** not usable in the current restricted execution context |
| Google Chrome | 152.0.7977.64 | **Fact:** executable and version query work; browser integration is not configured |
| Docker Engine client | 29.7.2 | **Fact:** client exists; access to the Docker daemon socket is denied in the current sandbox |
| Docker Compose | v5.5.0 | **Fact:** plugin is available; runtime use depends on Docker daemon access |
| Git | 2.53.0 | **Fact:** repository operations are available |

No software was installed and no project dependency was introduced during Prompt 000.

## Integrity and security inspection

- **Fact:** `ruby tracking/scripts/validate_blueprint.rb` validates the blueprint structure and counts.
- **Fact:** the assembly `SHA256SUMS` check passed for every listed file except `AGENTS.md` before tracker mutation. That known drift is explained by the already committed, user-requested Git completion workflow added after package assembly.
- **Fact:** Prompt execution intentionally mutates tracker state/log files, so the immutable assembly checksum list is evidence of the original package rather than an invariant for the evolving repository.
- **Fact:** filename-only scans found no tracked private-key blocks and no strings matching the selected AWS, Google, GitHub, Stripe, or Slack credential formats.
- **Fact:** a filename-only scan for common inline password/token/secret assignments returned no matches.
- **Fact:** file-type inspection found no tracked executable binaries, archives, databases, images, audio, video, or font artifacts.
- **Fact:** no file outside `.git/` exceeded 1 MiB.

Security inspection commands were deliberately configured to return filenames only for any match; secret-like values were not printed or copied into this report. These bounded pattern scans reduce obvious exposure risk but do not prove that arbitrary prose contains no sensitive information.

## Compatibility risks and missing prerequisites

1. **Fact:** Ruby 4.0.5 does not match the dated Ruby 3.4.10 blueprint candidate.
2. **Fact:** the PostgreSQL client is missing from the current command path.
3. **Fact:** Docker daemon access is denied in the current sandbox, preventing container-backed verification without an approved execution path.
4. **Fact:** Snap Chromium cannot run in this sandbox; the system Google Chrome executable may be evaluated later for test/browser compatibility.
5. **Fact:** no dependency lockfiles or project runtime pins exist yet.
6. **Fact:** the repository has only a blueprint commit, so all application behavior, migrations, tests, and operations remain unimplemented by design.
7. **Assumption:** the current SSH remote credentials permit push. This must be confirmed by the Prompt 000 commit/push workflow and must not be inferred from the presence of the remote URL alone.

## Proposed initialization path

The following is a plan for Prompt 001 and later prompts, not work completed by Prompt 000:

1. Preserve every blueprint, prompt, schema, tracker, and this baseline document while generating the Rails application into the repository root.
2. Verify a supported Ruby patch version and Rails 8.1 compatibility before adding project version files and dependency locks. Do not silently adopt the globally installed Ruby 4.0.5.
3. Generate a PostgreSQL-backed Rails modular monolith without Devise, OmniAuth, Doorkeeper, Sidekiq, Redis, Elasticsearch, or Kubernetes.
4. Keep Minitest and prepare separate process roles from one codebase; later prompts configure PostgreSQL-backed Solid Queue, Solid Cache, and Solid Cable.
5. Establish repeatable local PostgreSQL and container access before any prompt that must verify database, locking, queue, or browser behavior.
6. Re-run blueprint/tracker validation, application tests, security checks, and a full diff review after initialization.

This proposed sequence follows the accepted ADRs and does not claim that Rails, PostgreSQL, CI, containers, authentication, tenancy, or any product feature is already operational.
