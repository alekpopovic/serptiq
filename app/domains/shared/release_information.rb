# frozen_string_literal: true

require "time"

module Shared
  class ReleaseInformation
    RELEASE_PATTERN = /\A[a-zA-Z0-9][a-zA-Z0-9_.:-]{0,127}\z/

    def self.call(settings: Rails.application.config.x.searchops, environment: Rails.env.to_s,
      ruby_version: RUBY_VERSION, rails_version: Rails.version)
      new(
        settings: settings,
        environment: environment,
        ruby_version: ruby_version,
        rails_version: rails_version
      ).call
    end

    def initialize(settings:, environment:, ruby_version:, rails_version:)
      @settings = settings
      @environment = environment
      @ruby_version = ruby_version
      @rails_version = rails_version
    end

    def call
      release = safe_release(@settings.fetch(:release_sha))
      release_payload = {
        id: release,
        commit: release,
        build_time: safe_build_time(@settings.fetch(:build_timestamp))
      }.freeze
      runtime_payload = {
        ruby: safe_version(@ruby_version),
        rails: safe_version(@rails_version)
      }.freeze
      {
        status: "ok",
        release: release_payload,
        environment: safe_environment,
        runtime: runtime_payload
      }.freeze
    end

    private

    def safe_release(value)
      candidate = value.presence || "unreleased"
      RELEASE_PATTERN.match?(candidate.to_s) ? candidate.to_s.freeze : "unknown"
    end

    def safe_build_time(value)
      return if value.blank?

      Time.iso8601(value.to_s).utc.iso8601
    rescue ArgumentError
      nil
    end

    def safe_environment
      candidate = @environment.to_s
      %w[development test staging production].include?(candidate) ? candidate.freeze : "unknown"
    end

    def safe_version(value)
      candidate = value.to_s
      candidate.match?(/\A\d+(?:\.\d+){1,3}(?:[-.][a-zA-Z0-9]+)*\z/) ? candidate.freeze : "unknown"
    end
  end
end
