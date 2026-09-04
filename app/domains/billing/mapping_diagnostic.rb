# frozen_string_literal: true

module Billing
  MappingDiagnostic = Data.define(
    :organization_id, :subscription_id, :provider, :environment, :status, :reason_code
  ) do
    def initialize(**attributes)
      %i[organization_id subscription_id provider environment status reason_code].each do |name|
        attributes[name] = attributes.fetch(name).to_s.freeze
      end
      super(**attributes)
      freeze
    end
  end
end
