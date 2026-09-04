# frozen_string_literal: true

module Authorization
  AccessRequest = Data.define(
    :actor_membership_id, :actor_organization_id, :permission_key, :organization_id,
    :project_id, :property_id, :resource, :entitlement_key, :metered_quantity,
    :idempotency_key, :usage_window, :usage_source, :reservation_expires_at, :evaluated_at
  ) do
    ENTITLEMENT_KEY_PATTERN = /\A[a-z][a-z0-9_.]{0,95}\z/

    def initialize(actor_membership:, permission_key:, organization:, project: nil, property: nil, resource: nil,
      entitlement_key: nil, metered_quantity: nil, idempotency_key: nil, usage_window: nil,
      usage_source: nil, reservation_expires_at: nil, evaluated_at: nil)
      actor_id = reference_id(actor_membership)
      actor_organization_id = if actor_membership.respond_to?(:organization_id)
        actor_membership.organization_id&.to_s
      end
      entitlement = normalize_entitlement_key(entitlement_key)
      metering = normalize_metering(
        quantity: metered_quantity,
        idempotency_key: idempotency_key,
        usage_window: usage_window,
        usage_source: usage_source,
        reservation_expires_at: reservation_expires_at,
        evaluated_at: evaluated_at
      )
      super(
        actor_membership_id: actor_id,
        actor_organization_id: actor_organization_id&.freeze,
        permission_key: permission_key.to_s.freeze,
        organization_id: reference_id(organization).to_s.freeze,
        project_id: reference_id(project),
        property_id: reference_id(property),
        resource: normalize_resource(resource),
        entitlement_key: entitlement,
        **metering
      )
      freeze
    end

    def authenticated?
      actor_membership_id.present?
    end

    def scope_type
      return "Property" if property_id
      return "Project" if project_id

      "Organization"
    end

    def scope_id
      property_id || project_id || organization_id
    end

    def entitlement?
      entitlement_key.present?
    end

    def metered?
      !metered_quantity.nil?
    end

    private

    def reference_id(value)
      candidate = value.respond_to?(:id) ? value.id : value
      candidate&.to_s&.freeze
    end

    def normalize_resource(value)
      return if value.nil?
      return value if value.is_a?(ResourceContext)

      raise ArgumentError, "resource must be an Authorization::ResourceContext"
    end

    def normalize_entitlement_key(value)
      return if value.nil?

      key = value.to_s
      raise ArgumentError, "entitlement key is invalid" unless ENTITLEMENT_KEY_PATTERN.match?(key)

      key.freeze
    end

    def normalize_metering(quantity:, idempotency_key:, usage_window:, usage_source:,
      reservation_expires_at:, evaluated_at:)
      values = [ quantity, idempotency_key, usage_window, usage_source, reservation_expires_at ]
      return empty_metering(evaluated_at) if values.all?(&:nil?)
      raise ArgumentError, "metered access context is incomplete" if values.any?(&:nil?)

      key = idempotency_key.to_s
      raise ArgumentError, "metered access idempotency key is invalid" unless
        key.valid_encoding? && key.bytesize.between?(1, 200)
      at = evaluated_at || Time.current
      unless [ at, reservation_expires_at ].all? { |value| value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone) }
        raise ArgumentError, "metered access time is invalid"
      end

      {
        metered_quantity: quantity,
        idempotency_key: key.freeze,
        usage_window: usage_window,
        usage_source: usage_source,
        reservation_expires_at: reservation_expires_at,
        evaluated_at: at
      }
    end

    def empty_metering(evaluated_at)
      raise ArgumentError, "evaluation time requires metered access" unless evaluated_at.nil?

      {
        metered_quantity: nil,
        idempotency_key: nil,
        usage_window: nil,
        usage_source: nil,
        reservation_expires_at: nil,
        evaluated_at: nil
      }
    end
  end
end
