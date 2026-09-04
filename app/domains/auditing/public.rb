# frozen_string_literal: true

module Auditing
  module Public
    module_function

    def record!(**attributes)
      RecordEvent.new.call(**attributes)
    end

    def audit_page(organization_id:, authorization:, filters: {}, page: nil)
      AuthorizeAccess.new.call(
        organization_id: organization_id,
        authorization: authorization,
        permission_key: "audit_log.read"
      )
      AuditQuery.new.call(organization_id: organization_id, filters: filters, page: page)
    end

    def export!(organization_id:, authorization:)
      AuthorizeAccess.new.call(
        organization_id: organization_id,
        authorization: authorization,
        permission_key: "audit_log.export"
      )
      raise ExportUnavailable
    end

    def consistency_issues
      ConsistencyReport.new.call
    end
  end
end
