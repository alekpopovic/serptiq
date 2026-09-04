# frozen_string_literal: true

module Billing
  class CreateCustomerPortal
    def self.from_settings(auditor:, settings: Rails.application.config.x.searchops,
      registry: ProviderRegistry.new(settings: settings))
      provider_key = settings.fetch(:billing_provider).to_s
      raise ProviderUnknown.new(reason_code: "billing_provider_disabled") if provider_key == "disabled"

      new(provider: registry.fetch(provider_key), environment: Rails.env.to_s, auditor: auditor)
    end

    def initialize(provider:, environment:, auditor:, clock: -> { Time.current })
      @provider = provider
      @environment = ValueNormalization.string!(environment, name: "environment", maximum: 16)
      raise ArgumentError, "billing environment is invalid" unless CustomerMapping::ENVIRONMENTS.include?(@environment)
      raise ArgumentError, "billing auditor is invalid" unless auditor.respond_to?(:record!)

      @clock = clock
      @auditor = auditor
    end

    def call(actor_membership:, organization:, request_key:, authorization:)
      organization = AuthorizeManagement.new.call(
        actor_membership: actor_membership,
        organization: organization,
        authorization: authorization
      )
      customer = Billing::Public.customer_mapping(
        organization_id: organization.id,
        provider: @provider.provider_key,
        environment: @environment
      )
      unless customer.organization_id == organization.id && customer.provider == @provider.provider_key
        raise ProviderMappingMissing.new(reason_code: "billing_customer_mapping_conflict")
      end

      link = @provider.customer_portal(
        customer: customer,
        idempotency_key: ValueNormalization.string!(
          request_key, name: "portal request key", maximum: 200
        )
      )
      validate_portal_link!(link)
      mapping = CustomerMapping.find_by!(
        organization_id: organization.id,
        provider: @provider.provider_key,
        environment: @environment,
        provider_customer_id: customer.reference
      )
      @auditor.record!(
        organization_id: organization.id,
        actor_membership_id: actor_membership.id,
        action: "billing.portal_created",
        target_type: "BillingCustomer",
        target_id: mapping.id,
        result: "succeeded",
        metadata: { provider: @provider.provider_key, operation: "customer_portal", status: "created" }
      )
      link
    end

    private

    def validate_portal_link!(link)
      return if link.is_a?(PortalLink) && link.provider == @provider.provider_key && link.expires_at > @clock.call

      raise ProviderFailure.new(
        provider: @provider.provider_key,
        operation: "customer_portal",
        category: "malformed_response",
        retryable: false
      )
    end
  end
end
