# frozen_string_literal: true

module Auditing
  class ExportUnavailable < Shared::Public::EntitlementError
    def initialize(reason_code: "audit_export_not_entitled")
      super
    end
  end
end
