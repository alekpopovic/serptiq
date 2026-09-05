# frozen_string_literal: true

module Shared
  module NetworkSafety
    class PublicRedirectPolicy
      attr_reader :initial_target

      def initialize(origin:, url:, approved_redirect_origins: nil)
        @initial_target = HttpTarget.new(url: url)
        normalized_origin = HttpTarget.new(url: "#{origin}/").origin
        raise Error.new(reason_code: "unsafe_destination") unless initial_target.origin == normalized_origin

        @approved_redirect_origins = normalize_approved_origins(approved_redirect_origins)
      rescue ArgumentError
        raise Error.new(reason_code: "malformed_response"), cause: nil
      end

      def redirect(current:, location:)
        raw = location.to_s
        raise Error.new(reason_code: "redirect_rejected") if raw.blank? || raw.match?(/[\u0000-\u0020\\]/)

        target = HttpTarget.new(url: Addressable::URI.join(current.url, raw).to_s)
        raise Error.new(reason_code: "redirect_rejected") if current.scheme == "https" && target.scheme == "http"
        raise Error.new(reason_code: "redirect_rejected") unless approved_origin?(target.origin)

        target
      rescue Addressable::URI::InvalidURIError, ArgumentError
        raise Error.new(reason_code: "redirect_rejected"), cause: nil
      end

      def approved_origin?(origin)
        @approved_redirect_origins.nil? || @approved_redirect_origins.include?(origin)
      end

      private

      def normalize_approved_origins(values)
        return if values.nil?

        Array(values).map { |value| HttpTarget.new(url: "#{value}/").origin }.uniq.freeze
      end
    end
  end
end
