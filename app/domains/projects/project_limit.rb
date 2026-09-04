# frozen_string_literal: true

require "digest"

module Projects
  class ProjectLimit
    ENTITLEMENT_KEY = "projects.max"

    def initialize(resolver: ->(**attributes) { Entitlements::Public.resolve(**attributes) })
      @resolver = resolver
    end

    def lock_and_check!(organization_id:, excluding_project_id: nil, at: Time.current)
      lock!(organization_id)
      resolution = @resolver.call(
        organization_id: organization_id, entitlement_key: ENTITLEMENT_KEY, at: at
      )
      limit = resolution.value if resolution.enabled? && resolution.value.is_a?(Integer)
      active = Project.active.where(organization_id: organization_id)
      active = active.where.not(id: excluding_project_id) if excluding_project_id
      active_count = active.count
      raise ProjectLimitReached.new(limit: limit || 0, active_count: active_count) unless
        limit && active_count < limit

      limit
    end

    private

    def lock!(organization_id)
      raise ArgumentError, "project limit lock requires a transaction" unless Project.connection.transaction_open?

      value = Digest::SHA256.hexdigest("projects.max:#{organization_id}").first(16).to_i(16)
      value -= 2**64 if value >= 2**63
      Project.connection.execute("SELECT pg_advisory_xact_lock(#{value})")
    end
  end
end
