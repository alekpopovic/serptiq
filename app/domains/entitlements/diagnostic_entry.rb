# frozen_string_literal: true

module Entitlements
  DiagnosticEntry = Data.define(:description, :security_sensitive, :resolution) do
    def initialize(description:, security_sensitive:, resolution:)
      super(
        description: description.to_s.freeze,
        security_sensitive: !!security_sensitive,
        resolution: resolution
      )
      freeze
    end

    delegate :key, :value, :value_type, :unit, :category, :state, :provenance,
      :reason_code, :override_source, :override_expires_at, to: :resolution

    def display_value
      return "Contract configuration required" if resolution.custom_required?
      return "Unavailable (configuration error)" if resolution.misconfigured?
      return value ? "Enabled" : "Disabled" if value_type == "boolean"

      "#{value} #{unit.humanize.downcase}"
    end
  end
end
