# frozen_string_literal: true

namespace :auditing do
  namespace :consistency do
    desc "Fail when audit actors or known targets are orphaned or cross-tenant"
    task check: :environment do
      issues = Auditing::Public.consistency_issues
      if issues.empty?
        puts "Audit consistency: passed (0 issues)"
      else
        issues.each do |issue|
          warn "audit_event=#{issue.audit_event_id} reason=#{issue.reason_code}"
        end
        abort "Audit consistency: failed (#{issues.length} issues)"
      end
    end
  end
end
