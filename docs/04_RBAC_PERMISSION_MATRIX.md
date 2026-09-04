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

| Key | Category | Risk | Meaning |
|---|---|---:|---|
| `organization.read` | Organization | low | View organization profile and settings |
| `organization.update` | Organization | medium | Update non-destructive organization settings |
| `organization.transfer` | Organization | critical | Transfer organization ownership |
| `organization.delete` | Organization | critical | Request organization deletion |
| `members.read` | Membership | low | View members and invitations |
| `members.invite` | Membership | high | Invite members |
| `members.update` | Membership | high | Suspend or update membership settings |
| `members.remove` | Membership | high | Remove members |
| `teams.read` | Authorization | low | View teams |
| `teams.manage` | Authorization | medium | Create and manage teams |
| `roles.read` | Authorization | low | View roles and permissions |
| `roles.manage` | Authorization | critical | Create or modify custom roles |
| `roles.assign` | Authorization | critical | Grant or revoke role assignments |
| `billing.read` | Billing | medium | View subscription, invoices, and billing state |
| `billing.manage` | Billing | critical | Start checkout, change, cancel, or resume subscription |
| `plans.read` | Billing | low | View available plans and effective entitlements |
| `usage.read` | Usage | low | View quotas, reservations, and usage |
| `projects.read` | Projects | low | View projects |
| `projects.create` | Projects | medium | Create a project |
| `projects.update` | Projects | medium | Update project settings |
| `projects.archive` | Projects | high | Archive or restore a project |
| `projects.delete` | Projects | critical | Request permanent project deletion |
| `properties.read` | Properties | low | View project properties |
| `properties.manage` | Properties | high | Create and update properties |
| `properties.verify` | Properties | high | Create and execute ownership verification |
| `scans.read` | Scanning | low | View scans and scan evidence |
| `scans.run` | Scanning | medium | Run manual or targeted scans |
| `scans.configure` | Scanning | high | Change crawl, render, and scheduling policy |
| `scans.cancel` | Scanning | medium | Cancel active scans |
| `findings.read` | Findings | low | View findings and evidence |
| `findings.triage` | Findings | medium | Change triage classification |
| `findings.suppress` | Findings | high | Suppress or mark false positive/risk accepted |
| `issues.read` | Issues | low | View issue workflow |
| `issues.manage` | Issues | medium | Create and change issue status/details |
| `issues.assign` | Issues | medium | Assign members or teams |
| `issues.comment` | Issues | low | Add and edit own comments |
| `issues.verify` | Issues | medium | Request or approve verification flows |
| `integrations.read` | Integrations | low | View connected providers and health |
| `integrations.manage` | Integrations | critical | Connect, update, or revoke integrations |
| `releases.read` | Releases | low | View releases and gate results |
| `releases.manage` | Releases | high | Register and update releases |
| `release_gates.manage` | Releases | critical | Configure blocking/advisory gate policies |
| `reports.read` | Reporting | low | View generated reports |
| `reports.generate` | Reporting | medium | Generate reports |
| `reports.export` | Reporting | medium | Download or export reports |
| `reports.schedule` | Reporting | high | Configure scheduled reports |
| `reports.branding` | Reporting | high | Configure white-label report branding |
| `notifications.read` | Notifications | low | View notification policies/endpoints |
| `notifications.manage` | Notifications | high | Configure notification channels and rules |
| `api_keys.read` | Developer | medium | View API key metadata |
| `api_keys.manage` | Developer | critical | Create or revoke API keys |
| `webhooks.read` | Developer | medium | View outgoing webhook configuration/deliveries |
| `webhooks.manage` | Developer | critical | Create, change, replay, or revoke webhooks |
| `audit_log.read` | Audit | high | View audit log |
| `audit_log.export` | Audit | critical | Export audit events |
| `data.export` | Privacy | critical | Request organization data export |
| `data.delete` | Privacy | critical | Request project/user/organization data deletion |

## 4. Scope rules

1. `Owner`, `Organization Admin`, and `Billing Admin` are organization-scoped system roles.
2. `SEO Lead`, `Developer`, `Content Editor`, `Analyst`, and `Viewer` may be assigned at organization or project scope.
3. At project scope, only project-safe permissions are considered; organization-only grants are filtered even if present in a role template.
4. A team assignment grants permissions only to active members of that team and organization.
5. Expired or revoked assignments grant nothing.
6. Permission union is allowed across active direct and team assignments. The MVP has no arbitrary deny assignment.
7. The last active owner cannot be removed, suspended, demoted, or allowed to leave.
8. Ownership transfer is a dedicated, re-authenticated domain operation; it is not a generic role assignment.
9. `roles.manage`, `api_keys.manage`, `webhooks.manage`, `integrations.manage`, billing actions, and deletion actions require recent authentication.
10. UI capability hints may hide unavailable actions, but controllers/services always enforce decisions.

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

## 6. Custom-role constraints

Custom roles are designed for Agency/Enterprise but can be hidden until shipped. They cannot grant permissions the creating administrator does not possess. System roles cannot be edited. A custom role cannot include ownership transfer, organization deletion, or platform-administration permissions.
