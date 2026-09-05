# frozen_string_literal: true

module Crawling
  class FetchPermitDecision < Data.define(
    :state, :reason_code, :scope, :retry_at, :permit, :limits
  )
    STATES = %w[acquired throttled canceled exhausted].freeze
    SCOPES = %w[global organization scan host].freeze

    def initialize(**attributes)
      state = attributes.fetch(:state).to_s
      reason = attributes[:reason_code]&.to_s
      scope = attributes[:scope]&.to_s
      permit = attributes[:permit]
      valid = STATES.include?(state) && (reason.nil? || CrawlUrl::FAILURE_PATTERN.match?(reason)) &&
        (scope.nil? || SCOPES.include?(scope)) &&
        (attributes[:retry_at].nil? || attributes[:retry_at].respond_to?(:utc)) &&
        attributes.fetch(:limits).is_a?(PressureLimits) &&
        ((state == "acquired") == permit.is_a?(FetchPermitGrant))
      raise ArgumentError, "fetch permit decision is invalid" unless valid

      super(
        state: state.freeze,
        reason_code: reason&.freeze,
        scope: scope&.freeze,
        retry_at: attributes[:retry_at],
        permit: permit,
        limits: attributes.fetch(:limits)
      )
      freeze
    end

    def acquired?
      state == "acquired"
    end

    def throttled?
      state == "throttled"
    end
  end
end
