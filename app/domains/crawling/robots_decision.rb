# frozen_string_literal: true

module Crawling
  class RobotsDecision < Data.define(
    :outcome, :reason_code, :snapshot_id, :parser_version, :artifact_sha256,
    :retrieved_at, :evaluated_url, :matched_rule
  )
    OUTCOMES = %w[allowed denied unknown].freeze

    def initialize(**attributes)
      outcome = attributes.fetch(:outcome).to_s
      raise ArgumentError, "robots outcome is invalid" unless OUTCOMES.include?(outcome)

      super(
        outcome: outcome.freeze,
        reason_code: attributes.fetch(:reason_code).to_s.freeze,
        snapshot_id: attributes.fetch(:snapshot_id).to_s.freeze,
        parser_version: Integer(attributes.fetch(:parser_version)),
        artifact_sha256: attributes[:artifact_sha256]&.to_s&.freeze,
        retrieved_at: attributes.fetch(:retrieved_at),
        evaluated_url: attributes.fetch(:evaluated_url).to_s.freeze,
        matched_rule: attributes[:matched_rule]&.then { |value| value.to_h.stringify_keys.freeze }
      )
      freeze
    end

    def allowed?
      outcome == "allowed"
    end

    def denied?
      outcome == "denied"
    end

    def unknown?
      outcome == "unknown"
    end

    def crawl_permitted?
      allowed?
    end
  end
end
