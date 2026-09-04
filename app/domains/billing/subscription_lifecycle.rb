# frozen_string_literal: true

module Billing
  module SubscriptionLifecycle
    STATUSES = %w[pending trialing active past_due paused canceled expired].freeze
    ACCESS_STATES = %w[pending full grace read_only suspended].freeze
    CURRENT_STATUSES = (STATUSES - [ "expired" ]).freeze
    STATUS_ACCESS = {
      "pending" => %w[pending],
      "trialing" => %w[full],
      "active" => %w[full],
      "past_due" => %w[grace read_only],
      "paused" => %w[read_only suspended],
      "canceled" => %w[full read_only],
      "expired" => %w[read_only]
    }.transform_values(&:freeze).freeze

    module_function

    def valid?(status:, access_state:)
      STATUS_ACCESS.fetch(status.to_s, []).include?(access_state.to_s)
    end
  end
end
