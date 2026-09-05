# frozen_string_literal: true

module Shared
  module NetworkSafety
    class ExactRedirectPolicy
      attr_reader :initial_target

      def initialize(origin:, url:, approved_redirect_origins: [])
        raise Error.new(reason_code: "unsafe_destination") if url.to_s.match?(/[?#]/)

        @initial_target = HttpTarget.new(url: url)
        normalized_origin = HttpTarget.new(url: "#{origin}/").origin
        raise Error.new(reason_code: "unsafe_destination") unless initial_target.origin == normalized_origin
        raise Error.new(reason_code: "unsafe_destination") if initial_target.request_uri.include?("?")

        @approved_origins = [ normalized_origin, *approved_redirect_origins.map do |candidate|
          HttpTarget.new(url: "#{candidate}/").origin
        end ].uniq.freeze
      rescue ArgumentError
        raise Error.new(reason_code: "malformed_response"), cause: nil
      end

      def redirect(current:, location:)
        raw = location.to_s
        if raw.blank? || raw.match?(/[?#]/)
          raise Error.new(reason_code: "redirect_rejected", evidence: { denial_stage: "redirect_policy" })
        end

        joined = Addressable::URI.join(current.url, raw).to_s
        target = HttpTarget.new(url: joined)
        allowed = @approved_origins.include?(target.origin) && target.path == initial_target.path &&
          !target.request_uri.include?("?") && !(current.scheme == "https" && target.scheme == "http")
        unless allowed
          raise Error.new(reason_code: "redirect_rejected", evidence: { denial_stage: "redirect_policy" })
        end

        target
      rescue Addressable::URI::InvalidURIError, ArgumentError
        raise Error.new(
          reason_code: "redirect_rejected",
          evidence: { denial_stage: "redirect_policy" }
        ), cause: nil
      end

      def approved_origin?(origin)
        @approved_origins.include?(origin.to_s)
      end
    end
  end
end
