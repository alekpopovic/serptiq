# frozen_string_literal: true

module Entitlements
  class BindSubscriptionContext
    def call(organization_id:, subscription_id:, plan_version_id:, subscription_revision:, active: true)
      validate_identifiers!(organization_id, subscription_id, plan_version_id)
      revision = Integer(subscription_revision)
      raise ArgumentError, "subscription revision is invalid" if revision.negative?

      context = SubscriptionContext.transaction do
        current = SubscriptionContext.where(organization_id: organization_id, active: true).lock.first
        if !active
          deactivate(current)
        else
          replace_current(current, organization_id, subscription_id, plan_version_id, revision)
        end
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

    def replace_current(current, organization_id, subscription_id, plan_version_id, revision)
      if current&.subscription_id == subscription_id.to_s
        current.update!(plan_version_id: plan_version_id, subscription_revision: revision, active: true)
        return current
      end

      current&.update!(active: false)
      replacement = SubscriptionContext.find_or_initialize_by(subscription_id: subscription_id)
      replacement.assign_attributes(
        organization_id: organization_id,
        plan_version_id: plan_version_id,
        subscription_revision: revision,
        active: true
      )
      replacement.save!
      replacement
    end
  end
end
