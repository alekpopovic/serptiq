# frozen_string_literal: true

require "digest"

module Billing
  class WebhookRequestHeaders
    ACCEPTED_MEDIA_TYPES = %w[application/json application/vnd.api+json].freeze

    def call(headers:, body_bytes:)
      content_type = header(headers, "content-type").to_s.split(";", 2).first.to_s.downcase
      raise WebhookMediaTypeUnsupported unless ACCEPTED_MEDIA_TYPES.include?(content_type)

      result = {
        "content_type" => content_type,
        "content_length" => body_bytes
      }
      user_agent = header(headers, "user-agent")
      result["user_agent_digest"] = Digest::SHA256.hexdigest(user_agent.to_s) if user_agent.present?
      ValueNormalization.metadata(result)
    end

    private

    def header(headers, expected)
      headers.to_h.each do |key, value|
        return value if key.to_s.downcase == expected
      end
      nil
    end
  end
end
