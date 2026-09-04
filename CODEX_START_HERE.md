# Start Here — Codex Execution

This blueprint is designed to be copied into a new Git repository and executed one prompt at a time.

## 1. Inspect the package

```bash
ruby tracking/scripts/prompt_tracker.rb validate
ruby tracking/scripts/prompt_tracker.rb status
ruby tracking/scripts/prompt_tracker.rb next
```

Expected initial next prompt:

```text
000 — Repository reconnaissance and baseline snapshot
```

## 2. Give Codex one prompt

Open and provide the complete contents of:

```text
prompts/000_repository_reconnaissance_and_baseline_snapshot.md
```

Codex must run the tracker `start` command before implementation and the `complete` or `block` command after real verification.

## 3. Continue sequentially

```bash
ruby tracking/scripts/prompt_tracker.rb next
```

Never paste all 120 prompts as one execution request. `prompts/ALL_PROMPTS.md` exists only for search and review.

## 4. Critical architecture rules

```text
Rails modular monolith
PostgreSQL only
Solid Queue + Solid Cache + Solid Cable
Hotwire/Turbo/Stimulus + ERB + Tailwind
native application-owned social sessions
provider-neutral billing, Lemon Squeezy first
RBAC != entitlement != quota
SSRF-safe crawler boundary
Chromium only in isolated render workers
private S3-compatible artifact storage
Docker + Kamal, no Kubernetes for MVP
```

## 5. Verification

The tracker itself can be tested without modifying project state:

```bash
ruby tracking/scripts/test_prompt_tracker.rb
```

A prompt is not complete because code was generated. It is complete only after its acceptance criteria and actual tests pass and the result record is written.
