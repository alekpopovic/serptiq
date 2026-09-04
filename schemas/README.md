# JSON Schemas

- `prompt_result.schema.json`: structured completion record produced by the tracker.
- `seo_rule_result.schema.json`: normalized versioned rule result.
- `release_event.schema.json`: incoming CI/CD release event.
- `outgoing_webhook_envelope.schema.json`: signed SearchOps event envelope.

Schemas use JSON Schema Draft 2020-12. Runtime implementation should validate size and authentication before or alongside schema parsing; schema validation alone is not a security boundary.
