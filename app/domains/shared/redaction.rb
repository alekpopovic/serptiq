# frozen_string_literal: true

require "uri"

module Shared
  class Redaction
    FILTERED = "[FILTERED]"
    FILTERED_URL = "[FILTERED_URL]"
    FILTERS = [
      :password,
      :passw,
      :passphrase,
      :secret,
      :token,
      :nonce,
      :pkce,
      :verifier,
      :api_key,
      :access_key,
      :authorization,
      :cookie,
      :credential,
      :signature,
      :private_key,
      :encryption_key,
      :_key,
      :email,
      :body,
      :html,
      :dom,
      :har,
      :lighthouse_json,
      :screenshot,
      :page_body,
      :raw_body,
      :provider_response,
      :provider_payload,
      :userinfo,
      /api[-_]?key/i,
      /client[-_]?secret/i,
      /(?:oauth|authorization)[-_]?code/i,
      /\Acode\z/i,
      /\Astate\z/i,
      /\Aerror_description\z/i,
      /\Aerror_uri\z/i,
      /\Aotp\z/i,
      /\Acvv\z/i,
      /\Acvc\z/i
    ].freeze

    def initialize(filters: FILTERS)
      @filter = ActiveSupport::ParameterFilter.new(filters)
    end

    def filter(value)
      value.is_a?(Hash) ? @filter.filter(value) : value
    end
    alias_method :headers, :filter

    def payload(value)
      value.is_a?(Hash) ? filter(value) : FILTERED
    end
    alias_method :structured_event, :payload

    def query(value)
      filtered_query(value.to_s)
    rescue ArgumentError, EncodingError
      FILTERED
    end

    def url(value)
      uri = URI.parse(value.to_s)
      if uri.userinfo
        uri.user = nil
        uri.password = nil
      end
      uri.query = filtered_query(uri.query) if uri.query
      uri.fragment = nil
      uri.to_s
    rescue ArgumentError, EncodingError, URI::InvalidURIError, URI::InvalidComponentError
      FILTERED_URL
    end

    private

    def filtered_query(query)
      pairs = URI.decode_www_form(query).map do |key, _value|
        safe_key = key.match?(/\A[a-zA-Z0-9_.-]{1,64}\z/) ? key : "filtered_key"
        [ safe_key, FILTERED ]
      end
      URI.encode_www_form(pairs)
    end
  end
end
