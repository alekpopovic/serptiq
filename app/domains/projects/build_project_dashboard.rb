# frozen_string_literal: true

module Projects
  class BuildProjectDashboard
    ACCESS_EXPLANATIONS = {
      "permission_missing" => "Your role does not include permission to run scans for this project.",
      "resource_unavailable" => "This project is read-only, so new scans are unavailable.",
      "subscription_read_only" => "The subscription currently permits retained data reads but not new scans.",
      "subscription_incomplete" => "Complete subscription setup before starting new scans.",
      "subscription_suspended" => "New scans are paused while subscription access is suspended.",
      "entitlement_disabled" => "Manual scans are disabled by the effective crawl.manual entitlement.",
      "entitlement_value_disabled" => "Manual scans are disabled by the effective crawl.manual entitlement."
    }.freeze

    def call(project:, property_page:, property_readiness:, scan_observation:, findings_read:, scan_access:,
      usage:, integration:, activity_page:, generated_at: Time.current)
      property_observation = property_observation(property_page, property_readiness)
      action = scan_action(project, property_readiness, scan_access, usage)
      ProjectDashboard.new(
        project: project,
        property_page: property_page,
        property_readiness: property_readiness,
        property_observation: property_observation,
        scan_observation: scan_observation,
        findings_observation: findings_observation(project, findings_read),
        usage: usage,
        integration: integration,
        activity_page: activity_page,
        checklist: checklist(project, property_readiness, scan_access, usage),
        scan_action: action,
        generated_at: generated_at
      )
    end

    private

    def property_observation(page, readiness)
      return DashboardObservation.new(kind: "properties", state: "unavailable") unless page && readiness
      return DashboardObservation.new(kind: "properties", state: "no_data") if readiness.total_count.zero?

      DashboardObservation.new(
        kind: "properties",
        state: "ready",
        label: "#{readiness.active_count} active",
        detail: "Persisted properties visible to your current project scope.",
        count: readiness.total_count
      )
    end

    def findings_observation(project, findings_read)
      return DashboardObservation.new(kind: "findings", state: "unavailable") unless project.active?
      return DashboardObservation.new(
        kind: "findings", state: "unavailable", detail: "Your current role cannot inspect finding observations."
      ) unless findings_read.allow?

      DashboardObservation.new(
        kind: "findings", state: "no_data", label: "No findings yet",
        detail: "Finding counts remain empty until a completed scan produces versioned rule evidence."
      )
    end

    def scan_action(project, readiness, access, usage)
      return denied("project_read_only", "This project is read-only, so new scans are unavailable.") unless
        project.active?
      return denied("properties_restricted", "Property readiness is unavailable to your current role.") unless readiness
      return denied("website_property_required", "Add an active website property before running a baseline scan.") unless
        readiness.website_ready?
      return denied("primary_environment_required", "Add an active primary environment before running a scan.") unless
        readiness.environment_ready?
      return denied("verification_required", "Verify at least one active website property before running a scan.") unless
        readiness.verification_ready?
      return denied(access.reason_code, access_explanation(access)) unless access.allow?
      return denied("usage_restricted", "Quota readiness is unavailable to your current role.") unless usage
      return denied("usage_unavailable", "A concrete crawl credit limit is required before scan admission.") if
        usage.unavailable?
      return denied("quota_exhausted", "The current monthly crawl credit quota is exhausted.") if usage.exhausted?

      DashboardAction.new(
        allowed: true,
        reason_code: "baseline_ready",
        explanation: "Verification, access, entitlement and quota observations are ready for scan admission."
      )
    end

    def denied(reason_code, explanation)
      DashboardAction.new(allowed: false, reason_code: reason_code, explanation: explanation)
    end

    def access_explanation(access)
      return ACCESS_EXPLANATIONS.fetch(access.reason_code, "Scan access is unavailable for the current account state.") unless
        access.stage == "entitlement"

      ACCESS_EXPLANATIONS.fetch("entitlement_disabled")
    end

    def checklist(project, readiness, access, usage)
      [
        lifecycle_item(project),
        readiness_item(
          key: "website", ready: readiness&.website_ready?, restricted: readiness.nil?,
          title: "Website property", action: "Add an active website or web application property."
        ),
        readiness_item(
          key: "environment", ready: readiness&.environment_ready?, restricted: readiness.nil?,
          title: "Primary environment", action: "Configure an active primary production environment."
        ),
        readiness_item(
          key: "verification", ready: readiness&.verification_ready?, restricted: readiness.nil?,
          title: "Ownership verification", action: "Verify control of at least one active website property."
        ),
        access_item(access),
        usage_item(usage)
      ].freeze
    end

    def lifecycle_item(project)
      DashboardChecklistItem.new(
        key: "project", state: project.active? ? "ready" : "unavailable",
        title: "Active project",
        detail: project.active? ? "The project accepts new work." : "Reactivate the project before starting work."
      )
    end

    def readiness_item(key:, ready:, restricted:, title:, action:)
      state = if restricted then "restricted" elsif ready then "ready" else "action_required" end
      detail = if restricted
        "Your current role cannot inspect this readiness signal."
      elsif ready
        "Ready from persisted configuration."
      else
        action
      end
      DashboardChecklistItem.new(key: key, state: state, title: title, detail: detail)
    end

    def access_item(access)
      DashboardChecklistItem.new(
        key: "scan_access", state: access.allow? ? "ready" : "restricted",
        title: "Scan permission and entitlement",
        detail: access.allow? ? "The current access decision permits manual scan admission." : access_explanation(access)
      )
    end

    def usage_item(usage)
      state = if usage.nil?
        "restricted"
      elsif usage.exhausted? || usage.unavailable?
        "action_required"
      else
        "ready"
      end
      detail = if usage.nil?
        "Your current role cannot inspect project quota readiness."
      elsif usage.exhausted?
        "The current monthly crawl credit quota is exhausted."
      elsif usage.unavailable?
        "No concrete crawl credit limit is available."
      else
        "Crawl credits remain available according to the local usage ledger."
      end
      DashboardChecklistItem.new(key: "quota", state: state, title: "Crawl credit quota", detail: detail)
    end
  end
end
