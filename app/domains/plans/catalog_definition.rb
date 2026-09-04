# frozen_string_literal: true

module Plans
  CatalogDefinition = Data.define(
    :key, :display_name, :version, :positioning, :currency, :pricing_kind,
    :monthly_price_cents, :annual_price_cents, :entitlements, :checksum, :display_order
  ) do
    def initialize(**attributes)
      attributes[:entitlements] = attributes.fetch(:entitlements).to_h.each_with_object({}) do |(key, value), result|
        result[key.to_s.dup.freeze] = value.is_a?(String) ? value.dup.freeze : value
      end.freeze
      super(**attributes)
      freeze
    end

    def version_attributes(plan_id:)
      {
        plan_id: plan_id,
        version: version,
        display_name: display_name,
        positioning: positioning,
        currency: currency,
        pricing_kind: pricing_kind,
        monthly_price_cents: monthly_price_cents,
        annual_price_cents: annual_price_cents,
        entitlements_snapshot: entitlements,
        catalog_checksum: checksum
      }
    end
  end
end
