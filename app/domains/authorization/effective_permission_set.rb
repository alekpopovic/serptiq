# frozen_string_literal: true

module Authorization
  EffectivePermissionSet = Data.define(:permission_keys, :assignment_ids, :ownership, :sources_by_permission) do
    def initialize(permission_keys:, assignment_ids:, ownership: false, sources_by_permission: {})
      normalized_sources = sources_by_permission.to_h do |key, ids|
        [ key.to_s.freeze, ids.map { |value| value.to_s.freeze }.uniq.sort.freeze ]
      end.freeze
      super(
        permission_keys: permission_keys.map { |value| value.to_s.freeze }.uniq.sort.freeze,
        assignment_ids: assignment_ids.map { |value| value.to_s.freeze }.uniq.sort.freeze,
        ownership: !!ownership,
        sources_by_permission: normalized_sources
      )
      freeze
    end

    def include?(permission_key)
      permission_keys.include?(permission_key.to_s)
    end

    def owner?
      ownership
    end

    def sources_for(permission_key)
      sources_by_permission.fetch(permission_key.to_s, []).freeze
    end
  end
end
