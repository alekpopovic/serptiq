# frozen_string_literal: true

module Billing
  module Public
    module_function

    def create_subscription_reference(**attributes)
      CreateSubscriptionReference.new.call(**attributes)
    end
  end
end
