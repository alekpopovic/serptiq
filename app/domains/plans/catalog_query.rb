# frozen_string_literal: true

module Plans
  class CatalogQuery
    def call
      Plan.includes(:versions).order(:display_order).flat_map do |plan|
        plan.versions.sort_by { |version| -version.version }.map do |version|
          PlanVersionSummary.new(
            id: version.id,
            plan_key: plan.key,
            version: version.version,
            status: version.status,
            display_name: version.display_name,
            positioning: version.positioning,
            currency: version.currency,
            pricing_kind: version.pricing_kind,
            monthly_price_cents: version.monthly_price_cents,
            annual_price_cents: version.annual_price_cents,
            effective_at: version.effective_at
          )
        end
      end.freeze
    end
  end
end
