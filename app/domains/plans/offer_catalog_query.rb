# frozen_string_literal: true

module Plans
  class OfferCatalogQuery
    LOCKED_STATUSES = %w[published retired grandfathered].freeze

    def call(at: Time.current, current_plan_version_id: nil)
      validate_time!(at)
      current_id = current_plan_version_id&.to_s
      plans = Plan.includes(:versions).order(:display_order)
      plans.flat_map do |plan|
        current = plan.versions.find { |version| version.id.to_s == current_id }
        latest = plan.versions.select do |version|
          LOCKED_STATUSES.include?(version.status) && version.effective_at && version.effective_at <= at
        end.max_by(&:version)
        offered = latest if latest&.published?

        [ offered, current ].compact.uniq(&:id).map do |version|
          Offer.from_record(
            version,
            display_order: plan.display_order,
            offered: version.id == offered&.id,
            current: version.id.to_s == current_id
          )
        end
      end.freeze
    end

    private

    def validate_time!(at)
      return if at.is_a?(Time) || at.is_a?(ActiveSupport::TimeWithZone)

      raise CatalogTargetUnavailable.new(reason_code: "plan_catalog_time_invalid")
    end
  end
end
