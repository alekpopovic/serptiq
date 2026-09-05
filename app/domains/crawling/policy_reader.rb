# frozen_string_literal: true

module Crawling
  class PolicyReader
    def initialize(access: PolicyAccess.new, limit_resolver: ResolvePolicyLimits.new,
      defaults: DefaultPolicy.new, estimator: BuildCreditEstimate.new)
      @access = access
      @limit_resolver = limit_resolver
      @defaults = defaults
      @estimator = estimator
    end

    def call(actor_membership:, project_id:, property_id:, environment_id:, at: Time.current)
      context = @access.call(
        actor_membership: actor_membership, project_id: project_id,
        property_id: property_id, environment_id: environment_id
      )
      limits = @limit_resolver.call(organization_id: context.environment.organization_id, at: at)
      policy_set = PolicySet.find_by(identity(context.environment))
      record = policy_set&.current
      configuration = record ? record.configuration : @defaults.call(
        origin: context.environment.origin, limits: limits
      )
      PolicyView.new(
        configuration: configuration,
        version: record&.version || 0,
        limits: limits,
        estimate: @estimator.call(configuration: configuration, at: at),
        persisted: record.present?,
        robots_override_available: limits.robots_override && context.property.verified?
      )
    end

    private

    def identity(environment)
      {
        organization_id: environment.organization_id,
        project_id: environment.project_id,
        property_id: environment.property_id,
        environment_id: environment.id
      }
    end
  end
end
