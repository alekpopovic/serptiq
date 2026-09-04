# frozen_string_literal: true

module Entitlements
  class BuildDiagnosticReport
    def initialize(authorizer: DiagnosticAuthorizer.new, resolver: Resolver.new)
      @authorizer = authorizer
      @resolver = resolver
    end

    def call(organization_id:, authorization:, at: Time.current)
      @authorizer.call(organization_id: organization_id, authorization: authorization)
      definitions = Definition.order(:category, :key)
      context = SubscriptionContext.active.find_by(organization_id: organization_id)
      DiagnosticReport.new(
        entries: definitions.map do |definition|
          DiagnosticEntry.new(
            description: definition.customer_description,
            security_sensitive: definition.security_sensitive,
            resolution: @resolver.call(
              organization_id: organization_id,
              entitlement_key: definition.key,
              at: at
            )
          )
        end,
        plan_label: plan_label(context),
        subscription_revision: context&.subscription_revision
      )
    end

    private

    def plan_label(context)
      return "No active subscription — safe defaults" unless context

      snapshot = Plans::Public.version_snapshot(id: context.plan_version_id)
      "#{snapshot.display_name} v#{snapshot.version}"
    rescue Shared::Public::ConflictError
      "Unavailable subscription plan"
    end
  end
end
