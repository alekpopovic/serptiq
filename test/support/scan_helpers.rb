# frozen_string_literal: true

module TestSupport
  module ScanHelpers
    def create_scan_for(result, project:, property:, environment: property.environments.sole,
      scan_type: "full", at: Time.current, **overrides)
      Crawling::Public.create_scan(
        actor_membership: result.membership,
        project_id: project.id,
        property_id: property.id,
        environment_id: environment.id,
        scan_type: scan_type,
        settings_snapshot: { "max_urls" => 20, "robots_behavior" => "respect" },
        entitlement_snapshot: { "crawl.manual" => true, "crawl.max_urls_per_scan" => 500 },
        engine_version: "crawler-1.0.0",
        rule_set_version: "rules-1.0.0",
        clock: -> { at },
        **overrides
      )
    end

    def transition_scan(scan, command, at: Time.current, **attributes)
      Crawling::Public.transition_scan(
        organization_id: scan.organization_id,
        scan_id: scan.id,
        command: command,
        clock: -> { at },
        **attributes
      )
    end

    def run_scan_to(scan, target_status, at: Time.current)
      commands = %w[admit queue start complete]
      target_index = %w[admitted queued running completed].index(target_status.to_s)
      raise ArgumentError, "unsupported scan target status" unless target_index

      commands.first(target_index + 1).each_with_index do |command, index|
        scan = transition_scan(scan, command, at: at + index.seconds)
      end
      scan
    end
  end
end
