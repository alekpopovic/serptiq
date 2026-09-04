# RBAC Permission Matrix

## 1. Decision model

A role grant is only the authorization part of an action. Feature and usage checks remain separate:

```text
active authenticated membership
AND permission at the requested organization/project scope
AND enabled entitlement
AND available quota when metered
AND valid resource state
```

System roles are immutable templates. Assignments may be organization-scoped or project-scoped. A project-scoped assignment never grants organization administration, billing, membership, role, audit, privacy, or organization-wide integration rights.

Legend: **✓** default grant, **—** not granted. Owners receive every customer permission but remain subject to plan entitlements and quotas.

## 2. Default role matrix

| Permission | Owner | Organization Admin | Billing Admin | SEO Lead | Developer | Content Editor | Analyst | Viewer |
|---|---|---|---|---|---|---|---|---|
| `organization.read` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `organization.update` | ✓ | ✓ | — | — | — | — | — | — |
| `organization.transfer` | ✓ | — | — | — | — | — | — | — |
| `organization.delete` | ✓ | — | — | — | — | — | — | — |
| `members.read` | ✓ | ✓ | — | ✓ | ✓ | ✓ | ✓ | — |
| `members.invite` | ✓ | ✓ | — | — | — | — | — | — |
| `members.update` | ✓ | ✓ | — | — | — | — | — | — |
| `members.remove` | ✓ | ✓ | — | — | — | — | — | — |
| `teams.read` | ✓ | ✓ | — | ✓ | ✓ | ✓ | ✓ | — |
| `teams.manage` | ✓ | ✓ | — | — | — | — | — | — |
| `roles.read` | ✓ | ✓ | — | ✓ | ✓ | — | — | — |
| `roles.manage` | ✓ | ✓ | — | — | — | — | — | — |
| `roles.assign` | ✓ | ✓ | — | — | — | — | — | — |
| `billing.read` | ✓ | ✓ | ✓ | — | — | — | — | — |
| `billing.manage` | ✓ | — | ✓ | — | — | — | — | — |
| `plans.read` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — |
| `usage.read` | ✓ | ✓ | ✓ | ✓ | ✓ | — | ✓ | — |
| `projects.read` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `projects.create` | ✓ | ✓ | — | ✓ | — | — | — | — |
| `projects.update` | ✓ | ✓ | — | ✓ | ✓ | — | — | — |
| `projects.archive` | ✓ | ✓ | — | ✓ | — | — | — | — |
| `projects.delete` | ✓ | ✓ | — | — | — | — | — | — |
| `properties.read` | ✓ | ✓ | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| `properties.manage` | ✓ | ✓ | — | ✓ | ✓ | — | — | — |
| `properties.verify` | ✓ | ✓ | — | ✓ | ✓ | — | — | — |
| `scans.read` | ✓ | ✓ | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| `scans.run` | ✓ | ✓ | — | ✓ | ✓ | — | — | — |
| `scans.configure` | ✓ | ✓ | — | ✓ | ✓ | — | — | — |
| `scans.cancel` | ✓ | ✓ | — | ✓ | ✓ | — | — | — |
| `findings.read` | ✓ | ✓ | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| `findings.triage` | ✓ | ✓ | — | ✓ | ✓ | ✓ | — | — |
| `findings.suppress` | ✓ | ✓ | — | ✓ | — | — | — | — |
| `issues.read` | ✓ | ✓ | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| `issues.manage` | ✓ | ✓ | — | ✓ | ✓ | ✓ | — | — |
| `issues.assign` | ✓ | ✓ | — | ✓ | ✓ | ✓ | — | — |
| `issues.comment` | ✓ | ✓ | — | ✓ | ✓ | ✓ | — | — |
| `issues.verify` | ✓ | ✓ | — | ✓ | ✓ | ✓ | — | — |
| `integrations.read` | ✓ | ✓ | — | ✓ | ✓ | — | ✓ | — |
| `integrations.manage` | ✓ | ✓ | — | ✓ | — | — | — | — |
| `releases.read` | ✓ | ✓ | — | ✓ | ✓ | — | ✓ | ✓ |
| `releases.manage` | ✓ | ✓ | — | ✓ | ✓ | — | — | — |
| `release_gates.manage` | ✓ | ✓ | — | ✓ | ✓ | — | — | — |
| `reports.read` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `reports.generate` | ✓ | ✓ | — | ✓ | ✓ | ✓ | ✓ | — |
| `reports.export` | ✓ | ✓ | — | ✓ | ✓ | ✓ | ✓ | — |
| `reports.schedule` | ✓ | ✓ | — | ✓ | — | — | — | — |
| `reports.branding` | ✓ | ✓ | — | — | — | — | — | — |
| `notifications.read` | ✓ | ✓ | — | ✓ | ✓ | ✓ | ✓ | — |
| `notifications.manage` | ✓ | ✓ | — | ✓ | — | — | — | — |
| `api_keys.read` | ✓ | ✓ | — | — | ✓ | — | — | — |
| `api_keys.manage` | ✓ | ✓ | — | — | ✓ | — | — | — |
| `webhooks.read` | ✓ | ✓ | — | ✓ | ✓ | — | — | — |
| `webhooks.manage` | ✓ | ✓ | — | — | ✓ | — | — | — |
| `audit_log.read` | ✓ | ✓ | — | — | — | — | — | — |
| `audit_log.export` | ✓ | — | — | — | — | — | — | — |
| `data.export` | ✓ | ✓ | — | — | — | — | — | — |
| `data.delete` | ✓ | — | — | — | — | — | — | — |

## 3. Permission registry

| Key | Category | Risk | Scope | Meaning |
|---|---|---:|---|---|
| `organization.read` | Organization | low | organization | View organization profile and settings |
| `organization.update` | Organization | medium | organization | Update non-destructive organization settings |
| `organization.transfer` | Organization | critical | organization | Transfer organization ownership |
| `organization.delete` | Organization | critical | organization | Request organization deletion |
| `members.read` | Membership | low | organization | View members and invitations |
| `members.invite` | Membership | high | organization | Invite members |
| `members.update` | Membership | high | organization | Suspend or update membership settings |
| `members.remove` | Membership | high | organization | Remove members |
| `teams.read` | Authorization | low | organization | View teams |
| `teams.manage` | Authorization | medium | organization | Create and manage teams |
| `roles.read` | Authorization | low | organization | View roles and permissions |
| `roles.manage` | Authorization | critical | organization | Create or modify custom roles |
| `roles.assign` | Authorization | critical | organization | Grant or revoke role assignments |
| `billing.read` | Billing | medium | organization | View subscription, invoices, and billing state |
| `billing.manage` | Billing | critical | organization | Start checkout, change, cancel, or resume subscription |
| `plans.read` | Billing | low | organization | View available plans and effective entitlements |
| `usage.read` | Usage | low | project | View quotas, reservations, and usage |
| `projects.read` | Projects | low | project | View projects |
| `projects.create` | Projects | medium | organization | Create a project |
| `projects.update` | Projects | medium | project | Update project settings |
| `projects.archive` | Projects | high | project | Archive or restore a project |
| `projects.delete` | Projects | critical | project | Request permanent project deletion |
| `properties.read` | Properties | low | project | View project properties |
| `properties.manage` | Properties | high | project | Create and update properties |
| `properties.verify` | Properties | high | project | Create and execute ownership verification |
| `scans.read` | Scanning | low | project | View scans and scan evidence |
| `scans.run` | Scanning | medium | project | Run manual or targeted scans |
| `scans.configure` | Scanning | high | project | Change crawl, render, and scheduling policy |
| `scans.cancel` | Scanning | medium | project | Cancel active scans |
| `findings.read` | Findings | low | project | View findings and evidence |
| `findings.triage` | Findings | medium | project | Change triage classification |
| `findings.suppress` | Findings | high | project | Suppress or mark false positive/risk accepted |
| `issues.read` | Issues | low | project | View issue workflow |
| `issues.manage` | Issues | medium | project | Create and change issue status/details |
| `issues.assign` | Issues | medium | project | Assign members or teams |
| `issues.comment` | Issues | low | project | Add and edit own comments |
| `issues.verify` | Issues | medium | project | Request or approve verification flows |
| `integrations.read` | Integrations | low | organization | View connected providers and health |
| `integrations.manage` | Integrations | critical | organization | Connect, update, or revoke integrations |
| `releases.read` | Releases | low | project | View releases and gate results |
| `releases.manage` | Releases | high | project | Register and update releases |
| `release_gates.manage` | Releases | critical | project | Configure blocking/advisory gate policies |
| `reports.read` | Reporting | low | project | View generated reports |
| `reports.generate` | Reporting | medium | project | Generate reports |
| `reports.export` | Reporting | medium | project | Download or export reports |
| `reports.schedule` | Reporting | high | project | Configure scheduled reports |
| `reports.branding` | Reporting | high | organization | Configure white-label report branding |
| `notifications.read` | Notifications | low | project | View notification policies/endpoints |
| `notifications.manage` | Notifications | high | project | Configure notification channels and rules |
| `api_keys.read` | Developer | medium | project | View API key metadata |
| `api_keys.manage` | Developer | critical | project | Create or revoke API keys |
| `webhooks.read` | Developer | medium | project | View outgoing webhook configuration/deliveries |
| `webhooks.manage` | Developer | critical | project | Create, change, replay, or revoke webhooks |
| `audit_log.read` | Audit | high | organization | View audit log |
| `audit_log.export` | Audit | critical | organization | Export audit events |
| `data.export` | Privacy | critical | organization | Request organization data export |
| `data.delete` | Privacy | critical | organization | Request project/user/organization data deletion |

## 4. Scope rules

1. `Owner`, `Organization Admin`, and `Billing Admin` are organization-scoped system roles.
2. `SEO Lead`, `Developer`, `Content Editor`, `Analyst`, and `Viewer` may be assigned at organization,
   project, or narrower property scope; property scope uses the role's project assignability.
3. At project scope, only project-safe permissions are considered; organization-only grants are filtered even if present in a role template.
4. A team assignment grants permissions only to active members of that team and organization.
5. Expired or revoked assignments grant nothing.
6. Permission union is allowed across active direct and team assignments. The MVP has no arbitrary deny assignment.
7. The last active owner cannot be removed, suspended, demoted, or allowed to leave.
8. Ownership transfer is a dedicated, re-authenticated domain operation; it is not a generic role assignment.
9. `roles.manage`, `api_keys.manage`, `webhooks.manage`, `integrations.manage`, billing actions, and deletion actions require recent authentication.
10. UI capability hints may hide unavailable actions, but controllers/services always enforce decisions.
11. Organization grants flow to descendant projects and properties, project grants flow to descendant
    properties, and property grants apply only to that exact property. Grants are unioned; no scope flows upward.
12. Suspended/removed memberships, archived teams, archived target scopes, expired assignments and revoked
    assignments contribute no permissions. An archived parent project also disables property grants.
    To preserve reviewable project history, `projects.read`, `projects.archive` (restore), and
    `projects.delete` may be evaluated against an archived project using current organization-scope grants
    only; assignments scoped to that archived project remain ineffective.
13. Generic role assignment cannot grant `Owner`; ownership changes use the dedicated transfer operation.
14. Accepted invitation role intent passes through the same assignment authority and tenant checks; membership
    activation and the initial grant commit atomically.

## 5. Suggested policy API

```ruby
decision = Authorization::Decision.call(
  membership: Current.membership,
  permission: "scans.run",
  scope: project
)

decision.allow?       # boolean
decision.reason_code # stable machine-readable reason
decision.sources     # role assignments that contributed
```

Stable denial reasons include `not_authenticated`, `membership_inactive`, `scope_mismatch`, `permission_missing`, `recent_auth_required`, and `resource_unavailable`. Entitlement and quota denials use their own services and codes.

The implemented RBAC decision is deliberately uncached. A role grant/revocation, team lifecycle change, or
membership lifecycle change is therefore visible to the next decision, including later decisions in the same
request. Request/value objects may carry a typed resource context, but never an entitlement or quota result.

## 6. Custom-role constraints

Custom roles are designed for Agency/Enterprise but can be hidden until shipped. They cannot grant permissions the creating administrator does not possess. System roles cannot be edited. A custom role cannot include ownership transfer, organization deletion, or platform-administration permissions.
## 7. Enforcement inventory

The executable controller, domain-operation and background-job mapping lives in
`config/authorization_inventory.yml`. Tenant controller declarations are checked by
`script/check_authorization_coverage` as part of `bin/quality`. Backend enforcement happens before tenant
records or list relations are loaded; view capability hints consume an already evaluated decision and are
never authoritative.

Organization permissions are evaluated at the organization scope. Project permissions may be granted at the
organization or project scope. Property resources are authorized through their registered parent-project
hierarchy, and both tenant and parent-project linkage must match. Jobs reload explicit scalar tenant/resource
IDs and re-authorize at execution time so suspension, revocation and resource moves fail closed.
