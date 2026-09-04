# frozen_string_literal: true

require "digest"

module Properties
  class PropertyLimit
    GROUPS = {
      "website" => [ "website_properties.max", %w[website web_application] ],
      "web_application" => [ "website_properties.max", %w[website web_application] ],
      "android_app" => [ "mobile_properties.max", %w[android_app ios_app] ],
      "ios_app" => [ "mobile_properties.max", %w[android_app ios_app] ]
    }.freeze

    def initialize(resolver: ->(**attributes) { Entitlements::Public.resolve(**attributes) })
      @resolver = resolver
    end

    def lock_and_check!(organization_id:, kind:, excluding_property_id: nil, at: Time.current)
      entitlement_key, kinds = GROUPS.fetch(kind.to_s) do
        raise ArgumentError, "property type is unsupported"
      end
      lock!(organization_id, entitlement_key)
      resolution = @resolver.call(
        organization_id: organization_id, entitlement_key: entitlement_key, at: at
      )
      limit = resolution.value if resolution.enabled? && resolution.value.is_a?(Integer)
      active = Property.active.where(organization_id: organization_id, kind: kinds)
      active = active.where.not(id: excluding_property_id) if excluding_property_id
      active_count = active.count
      unless limit && active_count < limit
        raise PropertyLimitReached.new(
          entitlement_key: entitlement_key, limit: limit || 0, active_count: active_count
        )
      end

      limit
    end

    private

    def lock!(organization_id, entitlement_key)
      raise ArgumentError, "property limit lock requires a transaction" unless Property.connection.transaction_open?

      value = Digest::SHA256.hexdigest("#{entitlement_key}:#{organization_id}").first(16).to_i(16)
      value -= 2**64 if value >= 2**63
      Property.connection.execute("SELECT pg_advisory_xact_lock(#{value})")
    end
  end
end
