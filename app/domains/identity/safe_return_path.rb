# frozen_string_literal: true

require "uri"

module Identity
  module SafeReturnPath
    FALLBACK = "/dashboard"
    ALLOWED_ROOTS = [ FALLBACK ].freeze
    PATH_PATTERN = %r{\A/[A-Za-z0-9/_-]*\z}

    module_function

    def call(candidate, fallback: FALLBACK)
      uri = URI.parse(candidate.to_s)
      path = uri.path.to_s

      return fallback unless local_uri?(uri)
      return fallback unless PATH_PATTERN.match?(path)
      return fallback unless allowed_path?(path)

      path.freeze
    rescue ArgumentError, EncodingError, URI::InvalidURIError
      fallback
    end

    def local_uri?(uri)
      uri.scheme.nil? && uri.host.nil? && uri.userinfo.nil? && uri.port.nil? &&
        uri.path.start_with?("/") && !uri.path.start_with?("//") && !uri.path.include?("\\")
    end
    private_class_method :local_uri?

    def allowed_path?(path)
      ALLOWED_ROOTS.any? { |root| path == root || path.start_with?("#{root}/") }
    end
    private_class_method :allowed_path?
  end
end
