# frozen_string_literal: true

module Billing
  class SubscriptionTransitionInvalid < Shared::Public::ConflictError
  end
end
