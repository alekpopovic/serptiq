# frozen_string_literal: true

module Billing
  SubscriptionTransition = Data.define(
    :status, :access_state, :grace_ends_at, :access_expires_at, :ended_at
  ) do
    def initialize(status:, access_state:, grace_ends_at: nil, access_expires_at: nil, ended_at: nil)
      raise ArgumentError, "subscription lifecycle is invalid" unless
        SubscriptionLifecycle.valid?(status: status, access_state: access_state)

      super
      freeze
    end
  end
end
