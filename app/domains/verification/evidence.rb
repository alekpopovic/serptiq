# frozen_string_literal: true

module Verification
  module Evidence
    ALLOWED_KEYS = %w[
      matched record_count status_code byte_count final_origin_match provider_property_match
    ].freeze

    module_function

    def sanitize(value)
      source = value.is_a?(Hash) ? value : {}
      source.each_with_object({}) do |(key, item), output|
        name = key.to_s
        next unless ALLOWED_KEYS.include?(name)

        output[name] = case item
        when true, false then item
        when Integer then item.clamp(0, 1_000_000)
        else next
        end
      end.freeze
    end
  end
end
