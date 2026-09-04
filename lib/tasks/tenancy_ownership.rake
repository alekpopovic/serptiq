# frozen_string_literal: true

namespace :tenancy do
  namespace :ownership do
    desc "Fail when any organization violates the current-owner invariant"
    task check: :environment do
      issues = Tenancy::Public.ownership_consistency_issues
      if issues.empty?
        puts "Ownership consistency: passed (0 issues)"
      else
        issues.each do |issue|
          warn "organization=#{issue.organization_id} reason=#{issue.reason_code}"
        end
        abort "Ownership consistency: failed (#{issues.length} issues)"
      end
    end
  end
end
