# frozen_string_literal: true

require "uri"

module Billing
  class HostedUrlPolicy
    def initialize(application_origin: Rails.application.config.x.searchops.fetch(:application_origin))
      @origin = URI(application_origin.to_s)
      unless %w[http https].include?(@origin.scheme) && @origin.host.present? && @origin.userinfo.nil? &&
          [ "", "/" ].include?(@origin.path.to_s) && @origin.query.nil? && @origin.fragment.nil?
        raise ArgumentError, "application origin is invalid"
      end
    rescue URI::InvalidURIError
      raise ArgumentError, "application origin is invalid", cause: nil
    end

    def call(path)
      relative = URI(path.to_s)
      valid = relative.scheme.nil? && relative.host.nil? && relative.userinfo.nil? &&
        relative.path.start_with?("/") && relative.fragment.nil?
      raise ArgumentError, "hosted return path is invalid" unless valid

      URI.join(origin_with_slash, relative.to_s.delete_prefix("/")).to_s.freeze
    rescue URI::InvalidURIError
      raise ArgumentError, "hosted return path is invalid", cause: nil
    end

    private

    def origin_with_slash
      "#{@origin.scheme}://#{@origin.host}#{@origin.port == @origin.default_port ? "" : ":#{@origin.port}"}/"
    end
  end
end
