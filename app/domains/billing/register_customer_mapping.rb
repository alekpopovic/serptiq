# frozen_string_literal: true

module Billing
  class RegisterCustomerMapping
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(organization_id:, provider:, environment:, provider_customer_id:)
      attributes = normalized_attributes(
        organization_id: organization_id,
        provider: provider,
        environment: environment,
        provider_customer_id: provider_customer_id
      )
      existing = CustomerMapping.find_by(attributes.slice(:organization_id, :provider, :environment))
      return snapshot(existing) if existing && existing.provider_customer_id == attributes[:provider_customer_id]
      raise ProviderMappingMissing.new(reason_code: "billing_customer_mapping_conflict") if existing

      snapshot(CustomerMapping.create!(attributes.merge(created_at: @clock.call, updated_at: @clock.call)))
    rescue ActiveRecord::RecordNotUnique
      replay = CustomerMapping.find_by(attributes.slice(:organization_id, :provider, :environment))
      return snapshot(replay) if replay&.provider_customer_id == attributes[:provider_customer_id]

      raise ProviderMappingMissing.new(reason_code: "billing_customer_mapping_conflict"), cause: nil
    rescue ActiveRecord::RecordInvalid => error
      if error.record.errors.of_kind?(:organization_id, :taken) ||
          error.record.errors.of_kind?(:provider_customer_id, :taken)
        raise ProviderMappingMissing.new(reason_code: "billing_customer_mapping_conflict"), cause: nil
      end

      raise ProviderMappingMissing.new(reason_code: "billing_customer_mapping_invalid"), cause: error
    rescue ActiveRecord::InvalidForeignKey => error
      raise ProviderMappingMissing.new(reason_code: "billing_customer_mapping_invalid"), cause: error
    end

    private

    def normalized_attributes(organization_id:, provider:, environment:, provider_customer_id:)
      {
        organization_id: ValueNormalization.uuid!(organization_id, name: "organization"),
        provider: ValueNormalization.string!(
          provider, name: "provider", maximum: 32, pattern: ValueNormalization::PROVIDER_PATTERN
        ),
        environment: ValueNormalization.string!(
          environment, name: "environment", maximum: 16,
          pattern: /\A(?:development|test|staging|production)\z/
        ),
        provider_customer_id: ValueNormalization.string!(
          provider_customer_id, name: "customer reference", maximum: 191,
          pattern: ValueNormalization::REFERENCE_PATTERN
        )
      }
    end

    def snapshot(mapping)
      Customer.new(
        provider: mapping.provider,
        reference: mapping.provider_customer_id,
        organization_id: mapping.organization_id,
        created_at: mapping.created_at
      )
    end
  end
end
