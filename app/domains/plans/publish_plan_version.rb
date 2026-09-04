# frozen_string_literal: true

module Plans
  class PublishPlanVersion
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(plan_key:, version:, effective_at:, confirmation:, authorization:)
      authorize!(authorization)
      expected = "PUBLISH #{plan_key} VERSION #{version}"
      raise CatalogTransitionInvalid.new(reason_code: "plan_publish_confirmation_invalid") unless confirmation == expected

      PlanVersion.transaction do
        record = locked_version(plan_key, version)
        raise CatalogTransitionInvalid.new(reason_code: "plan_version_not_draft") unless record.status == "draft"

        now = @clock.call
        effective = effective_at || now
        updated = PlanVersion.where(id: record.id, status: "draft").update_all(
          status: "published",
          effective_at: effective,
          published_at: now,
          updated_at: now,
          lock_version: record.lock_version + 1
        )
        raise CatalogTransitionInvalid.new(reason_code: "plan_publish_conflict") unless updated == 1

        Auditing::Public.record!(
          actor_user_id: authorization.actor_user_id,
          action: "plan.version_published",
          target_type: "PlanVersion",
          target_id: record.id,
          result: "succeeded",
          metadata: { operation: "publish", status: "published" }
        )
        record.reload
      end
    rescue StandardError => error
      audit_rejection("publish", plan_key, version, authorization, error)
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

    def audit_rejection(operation, plan_key, version, authorization, error)
      return unless Shared::Public.application_uuid?(authorization&.actor_user_id)

      record_id = PlanVersion.joins(:plan).find_by(plans: { key: plan_key }, version: version)&.id
      Auditing::Public.record!(
        actor_user_id: authorization.actor_user_id,
        action: "plan.version_publish_rejected",
        target_type: "PlanVersion",
        target_id: record_id,
        result: "denied",
        metadata: {
          operation: operation,
          reason_code: error.respond_to?(:reason_code) ? error.reason_code : "plan_publish_failed"
        }
      )
    end
  end
end
