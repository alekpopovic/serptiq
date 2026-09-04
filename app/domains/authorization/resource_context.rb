# frozen_string_literal: true

module Authorization
  ResourceContext = Data.define(:id, :type, :organization_id, :scope_type, :scope_id, :available) do
    def initialize(id:, type:, organization_id:, scope_type:, scope_id:, available: true)
      normalized_scope = scope_type.to_s.classify
      raise ArgumentError, "resource authorization scope is invalid" unless
        ScopeReference::TYPES.include?(normalized_scope)

      super(
        id: id.to_s.freeze,
        type: type.to_s.underscore.freeze,
        organization_id: organization_id.to_s.freeze,
        scope_type: normalized_scope.freeze,
        scope_id: scope_id.to_s.freeze,
        available: !!available
      )
      freeze
    end

    def available?
      available
    end
  end
end
