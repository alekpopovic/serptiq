# frozen_string_literal: true

module Authorization
  DecisionResult = Data.define(
    :allowed, :reason_code, :permission_key, :organization_id, :scope_type, :scope_id, :sources
  ) do
    def initialize(allowed:, reason_code:, permission_key:, organization_id:, scope_type:, scope_id:, sources: [])
      super(
        allowed: !!allowed,
        reason_code: reason_code.to_s.freeze,
        permission_key: permission_key.to_s.freeze,
        organization_id: organization_id.to_s.freeze,
        scope_type: scope_type.to_s.freeze,
        scope_id: scope_id.to_s.freeze,
        sources: sources.map { |value| value.to_s.freeze }.uniq.sort.freeze
      )
      freeze
    end

    def allow?
      allowed
    end

    def deny?
      !allowed
    end
  end
end
