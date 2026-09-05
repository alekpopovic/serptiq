# Quality and security checks

Run `bin/quality` from the repository root before committing. It stops at the
first failure and executes the same deterministic gates in this order:

1. Ruby style with the Rails Omakase RuboCop baseline;
2. ERB structure, unsafe contexts and embedded Ruby style;
3. JavaScript module syntax through the installed Node.js runtime;
4. every repository YAML/JSON file plus duplicate YAML keys;
5. blueprint, architecture, direct-network-client and crawler egress-policy contracts;
6. Tailwind compilation and importmap advisory audit;
7. Brakeman and locked-gem vulnerability audit.

Generated asset, runtime, dependency and vendor trees are the only global scan
exclusions. Application code and migrations remain in scope. `bin/quality`
does not replace `bin/rails test` or `bin/rails test:system`; run those against
PostgreSQL for the affected prompt. CI may present the same commands as
separate jobs while preserving their failure semantics.

## Baselines and findings

`.rubocop.yml` inherits `rubocop-rails-omakase` and pins the repository Ruby
target. `.erb_lint.yml` enables default structural rules, unsafe-context checks,
unused-disable detection and embedded RuboCop. `config/brakeman.yml` makes both
scanner errors and warnings fatal and rejects stale or undocumented ignored
warnings. Brakeman runs at the version locked by Bundler so the gate does not
depend on a live latest-release lookup; dependency automation proposes scanner
updates. `config/bundler-audit.yml` has no standing vulnerability ignores.

Fix a finding in application code or upgrade the dependency first. Do not use
`--force`, reduce scanner confidence or exclude an application directory to
make a gate green. A false positive should keep the narrowest possible scanner
fingerprint and an explanatory note.

## Temporary advisory waivers

A vulnerability waiver is exceptional and must be reviewed as a security
change. In the same commit that adds a CVE/GHSA to a scanner ignore file, add a
row to the table below with:

- advisory ID and a link to the primary advisory;
- affected locked package/version and why the vulnerable path is unreachable;
- accountable owner;
- UTC expiry date no more than 30 days away;
- tracking issue and the upgrade/removal plan.

Expired waivers fail review and must be removed or explicitly renewed with new
evidence. Brakeman ignore entries additionally require a non-empty note and are
checked for obsolete fingerprints. Never waive a finding because the fix is
inconvenient.

| Advisory | Package/version | Evidence and scope | Owner | Expires (UTC) | Tracking issue |
|---|---|---|---|---|---|
| None | — | No active waivers | — | — | — |

Update the advisory database with `bin/bundler-audit update` before triage.
For an accepted finding, record the scanner output and the successful complete
`bin/quality` and Rails test runs in the active prompt result.
