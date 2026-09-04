# frozen_string_literal: true

module Shared
  module Observability
    class << self
      attr_writer :emitter

      def emitter
        @emitter ||= EventEmitter.new
      end

      def runtime_attributes
        settings = Rails.application.config.x.searchops
        release = settings.fetch(:release_sha)

        {
          release: release.presence || "unreleased",
          environment: Rails.env.to_s
        }.freeze
      end
    end
  end
end
