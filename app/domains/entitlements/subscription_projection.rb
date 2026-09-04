# frozen_string_literal: true

module Entitlements
  SubscriptionProjection = Data.define(:subscription_id, :plan_version_id, :revision) do
    def initialize(**attributes)
      attributes[:subscription_id] = attributes.fetch(:subscription_id).to_s.freeze
      attributes[:plan_version_id] = attributes.fetch(:plan_version_id).to_s.freeze
      super(**attributes)
      freeze
    end
  end
end
