# frozen_string_literal: true

module Crawling
  class ResolveAdmissionPolicy
    def initialize(limit_resolver: ResolvePolicyLimits.new, defaults: DefaultPolicy.new,
      normalizer: NormalizePolicy.new, estimator: BuildCreditEstimate.new)
      @limit_resolver = limit_resolver
      @defaults = defaults
      @normalizer = normalizer
      @estimator = estimator
    end

    def call(environment:, at: Time.current)
      limits = @limit_resolver.call(organization_id: environment.organization_id, at: at)
      policy_set = PolicySet.find_by(
        organization_id: environment.organization_id,
        project_id: environment.project_id,
        property_id: environment.property_id,
        environment_id: environment.id
      )
      version = policy_set&.current
      configured = version&.configuration || @defaults.call(origin: environment.origin, limits: limits)
      effective = @normalizer.call(
        attributes: configured.to_h,
        origin: environment.origin,
        limits: limits
      )
      AdmissionPolicy.new(
        configuration: effective,
        policy_version: version&.version || 0,
        source_version: version,
        limits: limits,
        estimate: @estimator.call(configuration: effective, at: at)
      )
    end
  end
end
