# frozen_string_literal: true

namespace :billing do
  namespace :consistency do
    desc "Fail when canonical billing mappings or entitlement projections contain unexplained drift"
    task check: :environment do
      issues = Billing::Public.billing_consistency_issues
      if issues.empty?
        puts "Billing consistency: passed (0 issues)"
      else
        issues.each { |issue| warn "type=#{issue.type} count=#{issue.count}" }
        abort "Billing consistency: failed (#{issues.sum(&:count)} rows)"
      end
    end
  end

  namespace :operations do
    desc "Print the bounded billing alert snapshot without provider identifiers or payloads"
    task metrics: :environment do
      metrics = Billing::Public.operational_metrics(emit: true)
      puts "webhook_lag_seconds=#{metrics.webhook_lag_seconds} " \
        "dead_letters=#{metrics.dead_letter_count} " \
        "repeated_projection_failures=#{metrics.repeated_failure_count} " \
        "reconciliation_drift=#{metrics.drift_count} alerting=#{metrics.alerting}"
    end
  end
end
