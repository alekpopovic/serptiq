# frozen_string_literal: true

module Billing
  module SubscriptionLifecycle
    STATUSES = %w[pending incomplete trialing active past_due paused canceled expired].freeze
    ACCESS_STATES = %w[pending full grace read_only suspended].freeze
    CURRENT_STATUSES = (STATUSES - [ "expired" ]).freeze
    GRACE_PERIOD = 7.days
    STATUS_ACCESS = {
      "pending" => %w[pending],
      "incomplete" => %w[pending],
      "trialing" => %w[full],
      "active" => %w[full],
      "past_due" => %w[grace read_only],
      "paused" => %w[read_only suspended],
      "canceled" => %w[full read_only],
      "expired" => %w[read_only]
    }.transform_values(&:freeze).freeze
    TRANSITIONS = {
      "pending" => %w[incomplete trialing active canceled expired],
      "incomplete" => %w[trialing active canceled expired],
      "trialing" => %w[active past_due paused canceled expired],
      "active" => %w[past_due paused canceled expired],
      "past_due" => %w[active paused canceled expired],
      "paused" => %w[active past_due canceled expired],
      "canceled" => %w[active past_due paused expired],
      "expired" => %w[active]
    }.transform_values(&:freeze).freeze

    module_function

    def valid?(status:, access_state:)
      STATUS_ACCESS.fetch(status.to_s, []).include?(access_state.to_s)
    end

    def transition_allowed?(from:, to:)
      source = from.to_s
      target = to.to_s
      source == target || TRANSITIONS.fetch(source, []).include?(target)
    end

    def transition(from:, snapshot:, at: Time.current, current_grace_ends_at: nil)
      target = snapshot.status
      unless from.nil? || transition_allowed?(from: from, to: target)
        raise SubscriptionTransitionInvalid.new(reason_code: "subscription_transition_invalid")
      end

      grace_ends_at = if from.to_s == "past_due" && target == "past_due" && current_grace_ends_at
        current_grace_ends_at
      else
        grace_end(snapshot)
      end
      access_expires_at = target == "canceled" ? snapshot.access_expires_at : nil
      access_state = effective_access(
        status: target,
        access_state: snapshot.access_state,
        grace_ends_at: grace_ends_at,
        access_expires_at: access_expires_at,
        at: at
      )
      SubscriptionTransition.new(
        status: target,
        access_state: access_state,
        grace_ends_at: grace_ends_at,
        access_expires_at: access_expires_at,
        ended_at: snapshot.ended_at
      )
    end

    def effective_access(status:, access_state:, grace_ends_at:, access_expires_at:, at: Time.current)
      return "read_only" if status.to_s == "past_due" && grace_ends_at && at >= grace_ends_at
      return "read_only" if status.to_s == "canceled" && access_expires_at && at >= access_expires_at

      access_state.to_s
    end

    def grace_end(snapshot)
      return unless snapshot.status == "past_due"
      return snapshot.provider_updated_at if snapshot.access_state == "read_only"

      snapshot.provider_updated_at + GRACE_PERIOD
    end
  end
end
