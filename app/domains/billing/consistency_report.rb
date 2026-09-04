# frozen_string_literal: true

module Billing
  class ConsistencyReport
    def call
      counts = database_counts
      entitlement_counts.each { |type, count| counts[type] = counts.fetch(type, 0) + count }
      counts.filter_map do |type, count|
        ConsistencyIssue.new(type: type, count: count) if count.positive?
      end.sort_by(&:type).freeze
    end

    private

    def database_counts
      {
        "duplicate_customer_mapping" => duplicate_count(
          CustomerMapping, %i[provider environment provider_customer_id]
        ),
        "duplicate_subscription_mapping" => duplicate_count(
          Subscription.where.not(provider_subscription_id: nil),
          %i[provider provider_environment provider_subscription_id]
        ),
        "subscriber_without_plan_version" => missing_plan_version_count,
        "provider_subscription_without_customer" => Subscription.where.not(provider: nil)
          .where(billing_customer_id: nil).count
      }
    end

    def duplicate_count(relation, columns)
      relation.group(*columns).having("COUNT(*) > 1").count.values.sum
    end

    def missing_plan_version_count
      Subscription.connection.select_value(<<~SQL.squish).to_i
        SELECT COUNT(*)
        FROM subscriptions subscriptions
        LEFT JOIN plan_versions plan_versions ON plan_versions.id = subscriptions.plan_version_id
        WHERE plan_versions.id IS NULL
      SQL
    end

    def entitlement_counts
      Entitlements::Public.subscription_context_consistency_issues.to_h do |issue|
        [ issue.fetch(:type), issue.fetch(:count) ]
      end
    end
  end
end
