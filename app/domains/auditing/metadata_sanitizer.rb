# frozen_string_literal: true

module Auditing
  class MetadataSanitizer
    FILTERED = Shared::Public::FILTERED_VALUE
    ALLOWED_KEYS = %w[
      attempt_count billing_interval change_count changed_fields currency entitlement event_kind failure_category from
      method meter operation plan_version
      previous_version principal_type provider
      reason_code revoke_reason principal_id revoked_count role_id scope_id scope_type source status subscriber_count
      to units window_policy
    ].freeze
    IDENTIFIER_PATTERN = /\A[a-zA-Z][a-zA-Z0-9_.:-]{0,127}\z/
    SENSITIVE_KEY_PATTERN = /(?:body|cookie|credential|email|html|ip(?:_address)?|key|password|payload|secret|signature|token|user_agent)/i
    EMAIL_PATTERN = /\A[^\s@]+@[^\s@]+\z/
    USER_AGENT_PATTERN = /(?:Mozilla\/|AppleWebKit\/|Chrome\/|Firefox\/|Safari\/|curl\/)/i

    def call(value)
      source = value.is_a?(Hash) ? value : {}
      sanitized = source.each_with_object({}) do |(key, item), output|
        normalized_key = key.to_s
        next unless normalized_key.match?(/\A[a-z][a-z0-9_]{0,63}\z/)

        output[normalized_key] = if SENSITIVE_KEY_PATTERN.match?(normalized_key)
          FILTERED
        elsif ALLOWED_KEYS.include?(normalized_key)
          sanitize_value(item, depth: 0)
        end
      end.compact
      ensure_bounded!(sanitized)
    end

    private

    def sanitize_value(value, depth:)
      return FILTERED if depth > 2

      case value
      when String, Symbol
        sanitize_string(value.to_s)
      when Integer, Float, TrueClass, FalseClass, NilClass
        value
      when Array
        value.first(20).map { |item| sanitize_value(item, depth: depth + 1) }
      when Hash
        value.first(20).to_h do |key, item|
          safe_key = key.to_s.match?(IDENTIFIER_PATTERN) ? key.to_s : "filtered"
          [ safe_key, sanitize_value(item, depth: depth + 1) ]
        end
      else
        FILTERED
      end
    end

    def sanitize_string(value)
      bounded = value.encode("UTF-8", invalid: :replace, undef: :replace).byteslice(0, 256)
      return FILTERED if EMAIL_PATTERN.match?(bounded) || USER_AGENT_PATTERN.match?(bounded)

      bounded.match?(IDENTIFIER_PATTERN) ? bounded : FILTERED
    end

    def ensure_bounded!(value)
      return value.freeze if JSON.generate(value).bytesize <= 8.kilobytes

      {}.freeze
    end
  end
end
