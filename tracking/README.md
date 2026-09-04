# Prompt Execution Tracker

The tracker makes prompt execution sequential, auditable and recoverable. `tracking/prompt_catalog.csv` defines prompt metadata and dependencies. `tracking/state.json` stores mutable execution state. Do not edit either manually during normal work.

## Reasoning levels

| Level | Intended use |
|---|---|
| `low` | bounded documentation, presentation or mechanical configuration work |
| `medium` | ordinary Rails feature work with limited domain risk |
| `high` | architecture, multi-tenant data, provider integration, migrations or complex workflows |
| `xhigh` | authentication validation, authorization, billing projection, quota concurrency, SSRF, browser isolation, destructive lifecycle or production security |

The level is a minimum recommendation, not proof that a task is easy. Map it to the current Codex reasoning control available in the environment.

## Package-level validation

```bash
ruby tracking/scripts/validate_blueprint.rb
ruby tracking/scripts/test_prompt_tracker.rb
```

## Read-only commands

```bash
ruby tracking/scripts/prompt_tracker.rb validate
ruby tracking/scripts/prompt_tracker.rb status
ruby tracking/scripts/prompt_tracker.rb next
ruby tracking/scripts/prompt_tracker.rb show 040
ruby tracking/scripts/prompt_tracker.rb history
```

Use `--json` with `status`, `next` or `show` when machine-readable output is useful.

## Execute a prompt

Start only after reading `AGENTS.md`, the prompt and completed dependency results:

```bash
ruby tracking/scripts/prompt_tracker.rb start 000
```

Complete with actual evidence:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 000 \
  --summary "Recorded repository and toolchain baseline" \
  --test "git status --short --branch::passed::baseline captured" \
  --test "ruby tracking/scripts/prompt_tracker.rb validate::passed::catalog and state valid" \
  --files "docs/implementation/000_BASELINE.md" \
  --risks "Rails has not been initialized yet by design" \
  --next-steps "Execute prompt 001"
```

Test format:

```text
command::passed|failed|not_run::optional notes
```

A failed test prevents completion. `not_run` also prevents completion unless `--allow-not-run` is supplied deliberately; the reason must be visible in risks/next steps.

The legacy compact option remains supported:

```bash
--tests "bin/rails test: passed"
```

## Block and resume

```bash
ruby tracking/scripts/prompt_tracker.rb block 040 \
  --reason "PostgreSQL is unavailable; concurrency behavior cannot be verified"

ruby tracking/scripts/prompt_tracker.rb unblock 040 \
  --reason "PostgreSQL test service is now available"
```

A block is not a failure and must describe evidence and a safe next action. Never mark an incomplete prompt completed to keep the sequence moving.

## Reset

Reset is exceptional and requires a reason:

```bash
ruby tracking/scripts/prompt_tracker.rb reset 040 \
  --reason "Implementation was reverted"
```

If completed or active dependent prompts exist, the command refuses unless `--cascade` is given. Result files are moved into `tracking/results/archive/`, not erased.

## Files

```text
tracking/
  prompt_catalog.csv       immutable prompt metadata/dependencies
  state.json               mutable state protected by a file lock
  execution_log.jsonl      machine-readable append-only event log
  EXECUTION_LOG.md         human-readable completion/block log
  DECISIONS.md             implementation decisions not yet promoted to ADRs
  BLOCKERS.md              blocker journal
  HANDOFF.md               current-context handoff
  results/
    NNN.json               structured completion record
    NNN.md                 readable completion record
    archive/               results invalidated by reset
  templates/
    prompt_result.md
  scripts/
    prompt_tracker.rb
    test_prompt_tracker.rb
```

## Interrupted work recovery

1. Run `status` and inspect `current_prompt`.
2. Inspect Git status/diff and the in-progress prompt.
3. Continue only when the partial implementation is understood.
4. Block it with exact evidence when a prerequisite is missing.
5. Use reset only when the implementation/result is intentionally reverted.
6. Restore corrupt tracking files from Git and replay verified log information; never invent completion evidence.

## Integrity rules

- Exactly one prompt may be `in_progress`.
- Dependencies must be `completed` before `start`.
- Completed prompts require JSON and Markdown result files.
- Catalog checksum changes are rejected until reviewed and the state is intentionally regenerated/migrated.
- All writes use a lock and atomic state replacement.
- Validation is read-only.
- Tracker tests operate only in temporary directories.
