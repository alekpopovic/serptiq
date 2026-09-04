# frozen_string_literal: true

module TestSupport
  module UsageHelpers
    def sync_usage_catalog
      Authorization::Public.sync_catalog
      Plans::Public.sync_catalog
      Entitlements::Public.sync_catalog
      Usage::Public.sync_catalog
    end

    def create_subscribed_usage_organization(plan_key: "starter", slug: nil, user: nil)
      user ||= create_identity_user(display_name: "Usage Test Operator")
      grant = Plans::CatalogAccessGrant.active.find_by(
        user_id: user.id, permission: "plan_catalog.publish"
      )
      Plans::CatalogAccessGrant.create!(
        user_id: user.id, permission: "plan_catalog.publish", granted_at: Time.current
      ) unless grant
      authorization = Plans::Public.authorize_catalog!(
        user: user, permission: "plan_catalog.publish"
      )
      version = Plans::PlanVersion.joins(:plan).find_by!(plans: { key: plan_key }, version: 1)
      if version.status == "draft"
        version = publish_catalog_version(
          plan_key: plan_key, version: 1, authorization: authorization,
          effective_at: Time.current
        )
      end
      owner = create_organization_for(
        user: user,
        name: "#{plan_key.titleize} Usage Organization",
        slug: slug || "usage-#{SecureRandom.hex(4)}"
      )
      Billing::Public.create_subscription_reference(
        organization_id: owner.organization.id,
        plan_version_id: version.id,
        billing_interval: version.pricing_kind == "custom" ? "custom" : "monthly"
      )
      [ owner, authorization ]
    end

    def provider_usage_period(reference: "period-2026-01")
      Usage::BillingPeriod.new(
        starts_at: Time.utc(2026, 1, 1),
        ends_at: Time.utc(2026, 2, 1),
        time_zone_name: "UTC",
        reference: reference
      )
    end

    def resolve_usage_window(owner, meter_key: "crawl.http_fetch", at: Time.utc(2026, 1, 15),
      billing_period: provider_usage_period)
      Usage::Public.resolve_window(
        organization_id: owner.organization.id,
        meter_key: meter_key,
        at: at,
        billing_period: billing_period
      )
    end

    def usage_source(owner, type: "Scan", id: SecureRandom.uuid)
      Usage::SourceReference.new(
        organization_id: owner.organization.id,
        type: type,
        id: id
      )
    end
  end
end
