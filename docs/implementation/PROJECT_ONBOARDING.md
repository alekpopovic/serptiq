# Guided project and property onboarding

Prompt 057 adds an accessible, resumable path from an organization to a project, its website property,
optional Android/iOS properties and an ownership-verification attempt. The wizard persists business state on
the server; URLs and form fields identify only the draft, current step, requested direction and inputs for that
step. Hidden fields are never treated as authoritative workflow state.

## Access and tenant boundary

Every operation receives the current active membership and organization explicitly. The onboarding boundary
first applies the normal organization access policy for `projects.create`, then requires the complete
organization-scoped permission bundle needed by the atomic result:

- `projects.create`;
- `properties.manage`;
- `properties.verify`;
- `scans.configure`.

An organization-scoped grant may therefore create the child resources. A project- or property-scoped grant
cannot bootstrap a sibling project or expand its own scope. Draft lookup additionally matches the exact
organization and creating membership, so another member cannot inspect or complete saved inputs. The
controller inventory and domain public-operation inventory document every entry point.

## Persisted workflow

`project_onboarding_drafts` owns six ordered steps: project basics, product path, property/environment values,
verification method, bounded crawl preferences and review. Explicit columns hold normalized or bounded
values; customer input and security decisions are not stored in an opaque JSON state machine. UUIDs for the
future aggregates and the public project release key are allocated when the draft starts.

A PostgreSQL advisory transaction lock serializes starts for one organization/member, and a partial unique
index permits only one active draft for that pair. Row locks serialize movement and completion. A repeated
forward request for the step that just completed returns the current draft without applying a changed replay.
Back, forward and refresh therefore remain safe without JavaScript. Completion revalidates every saved value
and the current entitlements, then creates all selected aggregates and the non-Search-Console challenge in one
database transaction using the preallocated identifiers. Repeating completion returns the existing public
references and creates nothing again.

Cancellation deletes the temporary draft and its saved customer inputs. Completed drafts remain as bounded
setup evidence and an idempotency anchor. Organization or creating-membership deletion cascades temporary
draft cleanup.

## Plan impact and scan admission

The side panel is a read-only observation of current project, website-property and mobile-property counts and
their effective limits. It also reports the effective maximum URLs per scan and rendering availability. Values
are rechecked at completion because the observation is not a capacity guarantee.

The wizard does not reserve usage, create a scan, enqueue crawl work or claim future capacity. Initial crawl
preferences are validated against global bounds and current `crawl.manual`, `crawl.max_urls_per_scan` and
`crawl.javascript_rendering` entitlements. Prompt 058 owns the durable, versioned crawl-policy model and turns
these preferences into the full environment policy. A future explicit scan request must still pass permission,
entitlement, verification, resource-state and quota admission checks.

## Property and verification behavior

The website path accepts only a canonical public HTTP(S) origin through the Properties normalization API and
creates the normal primary production environment. The combined path may also create Android and/or iOS
properties after typed identifier validation. Display names must remain distinct inside the new project.

DNS TXT, HTML file and meta-tag selections issue the existing origin-bound challenge during completion.
Search Console selection does not silently choose an integration connection or provider property: after
creation the user must use the verification screen to select that exact provider evidence, which is rechecked
by the existing Search Console verification boundary. Until a challenge succeeds, the UI says ownership is
pending and never describes the property as verified.

The post-completion readiness list reports four independently observed facts: active project existence, exact
normalized primary origin, current ownership-verification summary and whether the saved initial settings still
fit the effective plan. It is informational and cannot start a crawl.

## Events and operations

The boundary emits `onboarding.started`, `onboarding.step_completed`, `onboarding.abandoned` and
`onboarding.completed`. Event attributes contain only a low-cardinality operation and outcome; project names,
origins, app identifiers and draft/resource IDs are excluded.

The migration creates one new, initially empty table. It takes ordinary PostgreSQL DDL/index locks while the
table is created, but performs no existing-row rewrite or backfill. Rollback drops only onboarding drafts; it
does not delete projects or properties already created by a completed workflow.
