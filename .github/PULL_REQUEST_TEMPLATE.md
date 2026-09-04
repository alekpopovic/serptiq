## Change summary

- Prompt/issue and intended outcome:
- Verification run (commands and actual results):

## Architecture and risk checklist

- [ ] Tenant ownership/isolation is unchanged, or cross-tenant denial is tested.
- [ ] Permissions and policy enforcement are unchanged, or backend checks and negative paths are tested.
- [ ] Entitlements and plan-independent feature keys are unchanged, or resolution behavior is tested.
- [ ] Quotas/reservations/idempotency are unchanged, or concurrency and retry behavior is tested with PostgreSQL.
- [ ] Migrations are absent, or constraints, indexes, lock risk, rollback and operational sequencing are documented.
- [ ] Provider contracts/payloads are unchanged, or adapters, signatures, idempotency and sanitized contract fixtures are tested.
- [ ] Security/privacy boundaries (secrets, redaction, hostile input, SSRF, browser isolation, retention) were reviewed.
- [ ] ADRs and module dependency rules are unaffected, or the index/decision and boundary configuration were updated.
- [ ] Customer-visible claims identify observations, provider data, heuristics and guarantees accurately.
- [ ] No credentials, private customer payloads or unrelated changes are included.

## Deployment and recovery

- Operational impact, feature gating and rollback/forward-fix plan:
