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
      :api_key,
      :access_key,
      :authorization,
      :cookie,
      :credential,
      :signature,
      :private_key,
      :encryption_key,
      :_key,
      :page_body,
      :raw_body,
      :userinfo,
      /api[-_]?key/i,
      /(?:oauth|authorization)[-_]?code/i,
      /\Acode\z/i,
      /\Astate\z/i,
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
    alias_method :structured_event, :filter

    def url(value)
      uri = URI.parse(value.to_s)
      if uri.userinfo
        uri.user = nil
        uri.password = nil
      end
      uri.query = filtered_query(uri.query) if uri.query
      uri.to_s
    rescue ArgumentError, EncodingError, URI::InvalidURIError, URI::InvalidComponentError
      FILTERED_URL
    end

    private

    def filtered_query(query)
      pairs = URI.decode_www_form(query).map do |key, value|
        [ key, @filter.filter(key => value).fetch(key) ]
      end
      URI.encode_www_form(pairs)
    end
  end
end
