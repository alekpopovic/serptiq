# frozen_string_literal: true

module Verification
  class SearchConsoleSelectionToken
    PURPOSE = "search-console-verification-selection"
    TTL = 10.minutes

    def initialize(verifier: Rails.application.message_verifier(PURPOSE))
      @verifier = verifier
    end

    def issue(connection_id:, external_property_identifier:)
      @verifier.generate(
        {
          "connection_id" => connection_id.to_s,
          "external_property_identifier" => external_property_identifier.to_s
        },
        purpose: PURPOSE,
        expires_in: TTL
      )
    end

    def verify(value)
      payload = @verifier.verify(value.to_s, purpose: PURPOSE)
      connection_id = payload.fetch("connection_id").to_s
      identifier = payload.fetch("external_property_identifier").to_s
      raise ActiveSupport::MessageVerifier::InvalidSignature unless
        Shared::Public.application_uuid?(connection_id) && identifier.bytesize.between?(1, 2048)

      [ connection_id.freeze, identifier.freeze ].freeze
    rescue ActiveSupport::MessageVerifier::InvalidSignature, KeyError, NoMethodError, TypeError
      raise SearchConsoleSelectionError, "provider_property_inaccessible"
    end
  end
end
