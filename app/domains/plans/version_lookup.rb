# frozen_string_literal: true

module Plans
  class VersionLookup
    def call(id:)
      version = PlanVersion.includes(:plan).find(id)
      VersionSnapshot.new(
        id: version.id,
        plan_key: version.plan.key,
        version: version.version,
        status: version.status,
        display_name: version.display_name,
        currency: version.currency,
        pricing_kind: version.pricing_kind,
        monthly_price_cents: version.monthly_price_cents,
        annual_price_cents: version.annual_price_cents
      )
    rescue ActiveRecord::RecordNotFound
      raise CatalogTransitionInvalid.new(reason_code: "plan_version_not_found"), cause: nil
    end
  end
end
