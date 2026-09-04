# frozen_string_literal: true

module Entitlements
  class BindSubscriptionContext
    def call(organization_id:, subscription_id:, plan_version_id:, subscription_revision:,
      subscription_status: "active", access_state: "full", grace_ends_at: nil,
      access_expires_at: nil, active: true)
      validate_identifiers!(organization_id, subscription_id, plan_version_id)
      revision = Integer(subscription_revision)
      raise ArgumentError, "subscription revision is invalid" if revision.negative?

      context = SubscriptionContext.transaction do
        current = SubscriptionContext.where(organization_id: organization_id, active: true).lock.first
        if !active
          deactivate(current)
        else
          replace_current(
            current, organization_id, subscription_id, plan_version_id, revision,
            subscription_status, access_state, grace_ends_at, access_expires_at
          )
        end
        verify_subscription_identity!
      end
      Current.entitlement_cache&.clear
      context
    rescue ActiveRecord::InvalidForeignKey, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
      raise CatalogConflict.new(reason_code: "entitlement_subscription_context_invalid"), cause: error
    end

    private

    def validate_identifiers!(*identifiers)
      raise ArgumentError, "subscription context identifier is invalid" unless
        identifiers.all? { |identifier| Shared::Public.application_uuid?(identifier) }
    end

    def deactivate(context)
      return unless context

      context.update!(active: false)
      context
    end

    def verify_subscription_identity!
      connection = SubscriptionContext.connection
      connection.execute("SET CONSTRAINTS fk_entitlement_contexts_subscription_identity IMMEDIATE")
      connection.execute("SET CONSTRAINTS fk_entitlement_contexts_subscription_identity DEFERRED")
    end

    def replace_current(current, organization_id, subscription_id, plan_version_id, revision,
      subscription_status, access_state, grace_ends_at, access_expires_at)
      projection = {
        plan_version_id: plan_version_id,
        subscription_revision: revision,
        subscription_status: subscription_status,
        access_state: access_state,
        grace_ends_at: grace_ends_at,
        access_expires_at: access_expires_at,
        active: true
      }
      if current&.subscription_id == subscription_id.to_s
        current.update!(projection)
        return current
      end

      current&.update!(active: false)
      replacement = SubscriptionContext.find_or_initialize_by(subscription_id: subscription_id)
      replacement.assign_attributes(
        organization_id: organization_id,
        **projection
      )
      replacement.save!
      replacement
    end
  end
end
