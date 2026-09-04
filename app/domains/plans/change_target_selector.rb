# frozen_string_literal: true

module Plans
  class ChangeTargetSelector
    def call(current_plan_version_id:, target_plan_key:, currency:, billing_interval:, at: Time.current)
      current = PlanVersion.includes(:plan).find(current_plan_version_id)
      target_snapshot = CurrentVersionSelector.new.call(
        plan_key: target_plan_key,
        currency: currency,
        billing_interval: billing_interval,
        at: at
      )
      raise CatalogTargetUnavailable.new(reason_code: "plan_target_unchanged") if target_snapshot.id == current.id

      target = PlanVersion.includes(:plan).find(target_snapshot.id)
      direction, policy = direction_and_policy(current, target)
      PlanChangeTarget.new(version: target_snapshot, direction: direction, effective_policy: policy)
    rescue ActiveRecord::RecordNotFound
      raise CatalogTargetUnavailable.new(reason_code: "current_plan_version_not_found"), cause: nil
    end

    private

    def direction_and_policy(current, target)
      comparison = target.plan.display_order <=> current.plan.display_order
      return [ "upgrade", "immediate" ] if comparison.positive?
      return [ "downgrade", "period_end" ] if comparison.negative?

      [ "migration", "explicit" ]
    end
  end
end
