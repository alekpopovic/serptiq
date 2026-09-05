# frozen_string_literal: true

module Crawling
  class WritePolicy
    def initialize(clock: -> { Time.current }, access: PolicyAccess.new,
      limit_resolver: ResolvePolicyLimits.new, normalizer: NormalizePolicy.new,
      defaults: DefaultPolicy.new)
      @clock = clock
      @access = access
      @limit_resolver = limit_resolver
      @normalizer = normalizer
      @defaults = defaults
    end

    def call(actor_membership:, project_id:, property_id:, environment_id:,
      attributes: nil, change_kind: "configured")
      now = @clock.call
      context = @access.call(
        actor_membership: actor_membership, project_id: project_id,
        property_id: property_id, environment_id: environment_id
      )
      limits = @limit_resolver.call(organization_id: context.environment.organization_id, at: now)
      configuration = if change_kind.to_s == "reset"
        @defaults.call(origin: context.environment.origin, limits: limits)
      else
        @normalizer.call(
          attributes: attributes || {}, origin: context.environment.origin, limits: limits
        )
      end
      write(context, configuration, change_kind.to_s, now)
    end

    private

    def write(context, configuration, change_kind, now)
      raise ArgumentError, "unsupported crawl policy change kind" unless
        PolicyVersion::CHANGE_KINDS.include?(change_kind)

      PolicyVersion.transaction do
        policy_set = PolicySet.create_or_find_by!(identity(context.environment))
        policy_set.lock!
        previous = policy_set.current&.configuration
        version_number = policy_set.current_version + 1
        version = PolicyVersion.create!(
          identity(context.environment).merge(
            crawl_policy_set_id: policy_set.id,
            version: version_number,
            **configuration.to_record_attributes,
            created_by_membership_id: context.authorization.authorization.actor_membership_id,
            change_kind: change_kind,
            created_at: now
          )
        )
        policy_set.update!(current_version: version_number, updated_at: now)
        PolicyAudit.record!(
          action: change_kind == "reset" ? "crawl_policy.reset" : "crawl_policy.updated",
          actor_membership_id: context.authorization.authorization.actor_membership_id,
          policy_set: policy_set,
          operation: change_kind,
          changed_fields: changed_fields(previous, configuration)
        )
        version
      end
    end

    def identity(environment)
      {
        organization_id: environment.organization_id,
        project_id: environment.project_id,
        property_id: environment.property_id,
        environment_id: environment.id
      }
    end

    def changed_fields(previous, current)
      return PolicyConfiguration.attribute_keys if previous.nil?

      PolicyConfiguration.attribute_keys.select do |key|
        previous.public_send(key) != current.public_send(key)
      end
    end
  end
end
