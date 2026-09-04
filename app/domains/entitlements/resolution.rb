# frozen_string_literal: true

module Entitlements
  Resolution = Data.define(
    :key, :value, :value_type, :unit, :category, :state, :provenance,
    :reason_code, :definition_checksum, :plan_version_id, :override_id,
    :override_source, :override_expires_at
  ) do
    def initialize(**attributes)
      %i[key value_type unit category state provenance reason_code definition_checksum override_source].each do |name|
        value = attributes[name]
        attributes[name] = value&.to_s&.freeze
      end
      attributes[:value] = attributes[:value].dup.freeze if attributes[:value].is_a?(String)
      super(**attributes)
      freeze
    end

    def enabled?
      state == "enabled"
    end

    def disabled?
      state == "disabled"
    end

    def custom_required?
      state == "custom_required"
    end

    def misconfigured?
      %w[unknown misconfigured].include?(state)
    end
  end
end
