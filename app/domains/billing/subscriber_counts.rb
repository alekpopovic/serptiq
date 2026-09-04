# frozen_string_literal: true

module Billing
  class SubscriberCounts
    def call(plan_version_ids:)
      ids = Array(plan_version_ids).map(&:to_s).select { |id| Shared::Public.application_uuid?(id) }.uniq
      counts = Subscription.where(status: "active", plan_version_id: ids).group(:plan_version_id).count
      ids.to_h { |id| [ id, counts.fetch(id, 0) ] }.freeze
    end
  end
end
