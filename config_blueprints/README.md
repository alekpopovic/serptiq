# Configuration Blueprints

These YAML files define intended seed/configuration contracts for implementation prompts. They are not runtime secrets and they are not a substitute for database-backed immutable snapshots.

- `permissions.yml`: permission catalog and system-role grants.
- `plans.yml`: plan tiers, prices for initial product design, credit weights and entitlement values.
- `seo_rules.yml`: initial versioned rule catalog.
- `release_policy.example.yml`: example release-regression gate.

Implementation must validate these files, load them idempotently and preserve historical database references. Removing a key from YAML must never silently erase in-use records.
