# frozen_string_literal: true

module Billing
  class CustomerMappingLookup
    def call(organization_id:, provider:, environment:)
      return missing unless Shared::Public.application_uuid?(organization_id)

      mapping = CustomerMapping.find_by(
        organization_id: organization_id,
        provider: provider.to_s,
        environment: environment.to_s
      )
      return missing unless mapping

      Customer.new(
        provider: mapping.provider,
        reference: mapping.provider_customer_id,
        organization_id: mapping.organization_id,
        created_at: mapping.created_at
      )
    end

    private

    def missing
      raise ProviderMappingMissing.new(reason_code: "billing_customer_mapping_missing")
    end
  end
end
