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

1. Run `status`, `show ID`, `history --limit 20` and inspect
   `current_prompt`.
2. Inspect Git status/diff, the active prompt and its dependency results. Resume
   the same ID without running `start` again when it is already `in_progress`.
3. Continue only when every partial change and recorded event is understood.
4. If a prerequisite is unavailable, run `block ID --reason "command, observed
   failure, and safe next action"`. Do not complete or reset merely to advance.
5. Once the same blocker is demonstrably resolved, run `unblock ID --reason
   "evidence of resolution"`, then `start ID` to begin a new attempt.
6. Use `reset ID --reason "implementation was reverted"` only after reverting
   that implementation. The tracker archives result files; `--cascade` is an
   explicit acknowledgement that dependent work is also invalidated.

If `state.json` is corrupt, first copy it and the append-only logs to a safe
temporary directory for diagnosis. Compare `execution_log.jsonl`,
`EXECUTION_LOG.md`, result files and Git history. Restore the last known-good
tracked state, for example:

```bash
git restore --source=<known-good-commit> -- tracking/state.json
```

Then replay only events whose implementation and evidence can be verified.
Never hand-edit a status or invent a completion. If logs and state disagree,
preserve both and document the reconciliation in `BLOCKERS.md` or `HANDOFF.md`
before resuming.

Record a failing check honestly as `command::failed::concise observed output`.
`complete` will refuse it and leave the prompt active. Fix and rerun the check;
the final passing test note should mention the earlier failure and correction.
If it cannot be fixed in scope, block the prompt with the exact command and
failure. Use `not_run` plus `--allow-not-run` only when the explicit risk and
next action are acceptable; it is not a synonym for passed.

## Integrity rules

- Exactly one prompt may be `in_progress`.
- Dependencies must be `completed` before `start`.
- Completed prompts require JSON and Markdown result files.
- Result JSON is checked against `schemas/prompt_result.schema.json` semantics
  and must agree with state timestamps, title, summary and optional commit.
- Catalog checksum changes are rejected until reviewed and the state is intentionally regenerated/migrated.
- All writes use a lock and atomic state replacement.
- Validation is read-only.
- Tracker tests operate only in temporary directories.
- CI may run `validate` and the isolated test suite, but must never run tracker
  mutation commands against the checkout.
