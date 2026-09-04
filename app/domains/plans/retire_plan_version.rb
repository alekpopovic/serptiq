# frozen_string_literal: true

module Plans
  class RetirePlanVersion
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(plan_key:, version:, confirmation:, authorization:, active_subscriber_count:)
      authorize!(authorization)
      subscriber_count = Integer(active_subscriber_count)
      raise CatalogTransitionInvalid.new(reason_code: "subscriber_count_invalid") if subscriber_count.negative?

      expected = "RETIRE #{plan_key} VERSION #{version}"
      raise CatalogTransitionInvalid.new(reason_code: "plan_retire_confirmation_invalid") unless confirmation == expected

      PlanVersion.transaction do
        record = locked_version(plan_key, version)
        destination = destination_status(record.status, subscriber_count)
        now = @clock.call
        updated = PlanVersion.where(id: record.id, status: record.status, lock_version: record.lock_version).update_all(
          status: destination,
          retired_at: now,
          updated_at: now,
          lock_version: record.lock_version + 1
        )
        raise CatalogTransitionInvalid.new(reason_code: "plan_retire_conflict") unless updated == 1

        Auditing::Public.record!(
          actor_user_id: authorization.actor_user_id,
          action: destination == "grandfathered" ? "plan.version_grandfathered" : "plan.version_retired",
          target_type: "PlanVersion",
          target_id: record.id,
          result: "succeeded",
          metadata: { operation: "retire", status: destination, subscriber_count: subscriber_count }
        )
        record.reload
      end
    rescue ArgumentError, TypeError
      error = CatalogTransitionInvalid.new(reason_code: "subscriber_count_invalid")
      audit_rejection(plan_key, version, authorization, error)
      raise error, cause: nil
    rescue StandardError => error
      audit_rejection(plan_key, version, authorization, error)
      raise
    end

    private

    def authorize!(authorization)
      valid = authorization&.allow? && authorization.permission_key == "plan_catalog.publish" &&
        Shared::Public.application_uuid?(authorization.actor_user_id)
      raise CatalogAccessDenied unless valid
    end

    def locked_version(plan_key, version)
      PlanVersion.joins(:plan).lock.find_by!(plans: { key: plan_key }, version: version)
    rescue ActiveRecord::RecordNotFound
      raise CatalogTransitionInvalid.new(reason_code: "plan_version_not_found"), cause: nil
    end

    def destination_status(status, subscriber_count)
      if status == "published"
        subscriber_count.positive? ? "grandfathered" : "retired"
      elsif status == "grandfathered" && subscriber_count.zero?
        "retired"
      else
        raise CatalogTransitionInvalid.new(reason_code: "plan_version_not_retirable")
      end
    end

    def audit_rejection(plan_key, version, authorization, error)
      return unless Shared::Public.application_uuid?(authorization&.actor_user_id)

      record_id = PlanVersion.joins(:plan).find_by(plans: { key: plan_key }, version: version)&.id
      Auditing::Public.record!(
        actor_user_id: authorization.actor_user_id,
        action: "plan.version_retire_rejected",
        target_type: "PlanVersion",
        target_id: record_id,
        result: "denied",
        metadata: {
          operation: "retire",
          reason_code: error.respond_to?(:reason_code) ? error.reason_code : "plan_retire_failed"
        }
      )
    end
  end
end
