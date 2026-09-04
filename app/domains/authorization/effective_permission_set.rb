# frozen_string_literal: true

module Authorization
  EffectivePermissionSet = Data.define(:permission_keys, :assignment_ids, :ownership) do
    def initialize(permission_keys:, assignment_ids:, ownership: false)
      super(
        permission_keys: permission_keys.map { |value| value.to_s.freeze }.uniq.sort.freeze,
        assignment_ids: assignment_ids.map { |value| value.to_s.freeze }.uniq.sort.freeze,
        ownership: !!ownership
      )
      freeze
    end

    def include?(permission_key)
      permission_keys.include?(permission_key.to_s)
    end

    def owner?
      ownership
    end
  end
end
