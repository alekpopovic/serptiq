# frozen_string_literal: true

module Administration
  class RetirePlanVersion
    def call(plan_key:, version:, confirmation:, authorization:)
      ApplicationRecord.transaction do
        snapshot = Plans::Public.catalog_version(plan_key: plan_key, version: version, lock: true)
        subscriber_count = Billing::Public.active_subscriber_count(plan_version_id: snapshot.id)
        Plans::Public.retire_version(
          plan_key: plan_key,
          version: version,
          confirmation: confirmation,
          authorization: authorization,
          active_subscriber_count: subscriber_count
        )
      end
    end
  end
end
