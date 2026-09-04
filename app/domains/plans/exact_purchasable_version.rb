# frozen_string_literal: true

module Plans
  class ExactPurchasableVersion
    def call(id:, currency:, billing_interval:, at: Time.current)
      normalized_currency = normalize_currency(currency)
      normalized_interval = normalize_interval(billing_interval)
      version = PlanVersion.includes(:plan).find(id)
      current = CurrentVersionSelector.new.call(
        plan_key: version.plan.key,
        currency: normalized_currency,
        billing_interval: normalized_interval,
        at: at
      )
      valid = current.id == version.id && version.published? &&
        version.currency == normalized_currency && version.pricing_kind == "fixed"
      raise CatalogTargetUnavailable.new(reason_code: "plan_version_not_purchasable") unless valid

      VersionSnapshot.from_record(version)
    rescue ActiveRecord::RecordNotFound, ArgumentError
      raise CatalogTargetUnavailable.new(reason_code: "plan_version_not_purchasable"), cause: nil
    end

    private

    def normalize_currency(value)
      normalized = value.to_s
      raise ArgumentError unless /\A[A-Z]{3}\z/.match?(normalized)

      normalized
    end

    def normalize_interval(value)
      normalized = value.to_s
      raise ArgumentError unless %w[monthly annual].include?(normalized)

      normalized
    end
  end
end
