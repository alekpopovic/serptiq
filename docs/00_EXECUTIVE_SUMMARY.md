# Executive Summary

## Product

**SearchOps** is a multi-tenant SaaS platform for continuously improving and protecting search visibility across websites, public web applications, Android applications, and iOS applications.

Its operating loop is:

```text
discover → collect evidence → prioritize → assign → fix → verify → measure → prevent regression
```

The product is intentionally positioned between point-in-time desktop crawlers, enterprise SEO suites, ASO tools, and generic project-management systems. It does not attempt to build a global backlink or keyword index in the MVP.

## Target customers

Primary initial customers:

1. digital and SEO agencies managing several client properties;
2. product-led SaaS companies with a marketing site, public application pages, and mobile apps;
3. e-commerce companies with web and native applications;
4. engineering organizations that need SEO release quality gates;
5. internal SEO teams that need accountable remediation rather than another issue export.

The initial ideal customer profile is an agency or product company with 5–50 employees, multiple public properties, recurring deployments, and no unified SearchOps workflow.

## Core product capabilities

- Organizations, projects, members, invitations, teams, roles, permissions, and scoped access.
- Versioned plans, subscriptions, billing, entitlements, quotas, usage reservations, and overage-safe behavior.
- Website ownership verification and controlled project onboarding.
- Static HTTP crawling, sitemap discovery, robots interpretation, URL normalization, internal-link graphing, and evidence storage.
- Isolated JavaScript rendering and source-versus-rendered analysis.
- Technical SEO rules for status codes, redirects, indexability, canonicalization, hreflang, metadata, headings, content, internal links, images, structured data, mobile parity, and crawler accessibility.
- Google Search Console, URL Inspection, CrUX, and Lighthouse integration.
- Android App Links and iOS Universal Links validation.
- App Store and Google Play listing audits.
- Findings, occurrences, issue workflow, assignment, comments, risk acceptance, rescans, and automatic verification.
- Baselines, deployment records, regression comparison, configurable release gates, and CI/CD status reporting.
- Reports, scheduled scans, email, Slack, in-app notifications, outgoing webhooks, and API keys.
- Administrative operations, audit history, data retention, export, and deletion workflows.

## Architecture

The MVP is a modular Rails monolith with independently scalable process roles:

```text
web
scheduler
worker-default
worker-crawl
worker-render
worker-analysis
worker-report
```

All roles use one application image and one release. PostgreSQL is the only operational data technology for application state, Solid Queue, Solid Cache, and Solid Cable. Large immutable artifacts are stored in S3-compatible object storage.

## Non-negotiable architecture rules

- Tenant isolation is explicit and tested; no `default_scope`.
- Permission, entitlement, and quota decisions are separate.
- Billing provider payloads are projected into local subscription state.
- Raw webhook events are stored before asynchronous processing.
- User-controlled URLs never bypass network destination validation.
- JavaScript execution never occurs in the web process.
- Rule results are versioned and evidence-backed.
- Findings are durable identities; occurrences record when and where they were observed.
- External provider adapters are isolated behind application-owned interfaces.
- No service extraction without measured justification.

## MVP commercial hypothesis

| Plan | Monthly list price | Positioning |
|---|---:|---|
| Free | €0 | Evaluation and very small sites |
| Starter | €39 | Small teams and individual consultants |
| Growth | €129 | Product teams and established agencies |
| Agency | €349 | Multi-client workflow and white-label reporting |
| Enterprise | Custom | SSO, dedicated capacity, regional controls, SLA |

Prices and limits are hypotheses. They must be validated against acquisition, conversion, retention, and infrastructure cost data.

## Success criteria

The MVP is successful when a customer can:

1. sign in through a supported identity provider;
2. create an organization and project;
3. verify a domain;
4. purchase or activate a plan;
5. run a bounded, safe scan;
6. review evidence-backed findings;
7. assign and resolve an issue;
8. run verification and see the issue close or reopen;
9. connect Search Console and performance data;
10. configure a recurring scan and regression notification;
11. validate at least one Android or iOS deep-link configuration;
12. receive a release-gate result through an integration;
13. manage members and scoped access without cross-tenant leakage;
14. export or delete organization data according to policy.

## Primary product metric

**Verified remediation rate:** the percentage of actionable findings that are assigned, remediated, and automatically verified within the selected reporting period.

Supporting metrics include time to first verified issue, critical regression escape rate, median time to resolution, scheduled-scan success rate, trial-to-paid conversion, monthly retained organizations, and crawl infrastructure cost per euro of recurring revenue.
