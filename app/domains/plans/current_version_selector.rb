# frozen_string_literal: true

module Plans
  class CurrentVersionSelector
    INTERVALS = %w[monthly annual custom].freeze

    def call(plan_key:, currency:, billing_interval:, at: Time.current, lock: false)
      interval = billing_interval.to_s
      raise CatalogTargetUnavailable.new(reason_code: "billing_interval_unavailable") unless INTERVALS.include?(interval)

      relation = PlanVersion.joins(:plan).where(
        plans: { key: plan_key.to_s },
        currency: currency.to_s,
        status: %w[published retired grandfathered]
      ).where("effective_at <= ?", at).order(version: :desc)
      relation = relation.lock if lock
      version = relation.first
      raise CatalogTargetUnavailable unless version&.status == "published" && interval_available?(version, interval)

      VersionSnapshot.from_record(version)
    end

    private

    def interval_available?(version, interval)
      if version.pricing_kind == "custom"
        interval == "custom"
      else
        %w[monthly annual].include?(interval) && version.public_send("#{interval}_price_cents").present?
      end
    end
  end
end
