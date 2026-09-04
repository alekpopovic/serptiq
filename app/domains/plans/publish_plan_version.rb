# frozen_string_literal: true

require "time"

module Plans
  class PublishPlanVersion
    SCHEDULING_HORIZON = 1.year

    def initialize(catalog:, clock: -> { Time.current })
      @catalog = catalog
      @clock = clock
    end

    def call(plan_key:, version:, expected_previous_version:, catalog_checksum:, effective_at:,
      confirmation:, authorization:)
      authorize!(authorization)
      requested_version = strict_integer(version)
      requested_previous = strict_integer(expected_previous_version)
      definition = source_definition(plan_key, requested_version, catalog_checksum)
      expected = "PUBLISH #{plan_key} VERSION #{requested_version} AFTER #{requested_previous}"
      unless confirmation == expected
        raise CatalogTransitionInvalid.new(reason_code: "plan_publish_confirmation_invalid")
      end

      PlanVersion.transaction do
        plan = Plan.lock.find_by!(key: plan_key.to_s)
        record = plan.versions.lock.find_by!(version: requested_version)
        raise CatalogTransitionInvalid.new(reason_code: "plan_version_not_draft") unless record.status == "draft"
        unless record.catalog_checksum == definition.checksum
          raise CatalogTransitionInvalid.new(reason_code: "plan_draft_out_of_sync")
        end

        previous = plan.versions.where.not(status: "draft").maximum(:version) || 0
        unless requested_previous == previous && requested_version == previous + 1
          raise CatalogVersionBumpInvalid
        end

        now = @clock.call
        effective = normalize_effective_at(effective_at, now)
        updated = PlanVersion.where(id: record.id, status: "draft", lock_version: record.lock_version).update_all(
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
          metadata: { operation: "publish", status: "published", previous_version: previous }
        )
        record.reload
      end
    rescue ActiveRecord::RecordNotFound
      error = CatalogTransitionInvalid.new(reason_code: "plan_version_not_found")
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

    def source_definition(plan_key, version, checksum)
      definition = @catalog.definitions.find { |candidate| candidate.key == plan_key.to_s }
      valid = definition && definition.version == version && definition.checksum == checksum.to_s
      raise CatalogTransitionInvalid.new(reason_code: "plan_source_revision_changed") unless valid

      definition
    end

    def strict_integer(value)
      Integer(value.to_s, 10)
    rescue ArgumentError, TypeError
      raise CatalogVersionBumpInvalid, cause: nil
    end

    def normalize_effective_at(value, now)
      effective = if value.blank?
        now
      elsif value.respond_to?(:in_time_zone)
        value.in_time_zone
      else
        Time.iso8601(value.to_s).in_time_zone
      end
      valid = effective >= now - 1.minute && effective <= now + SCHEDULING_HORIZON
      raise CatalogTransitionInvalid.new(reason_code: "plan_effective_at_invalid") unless valid

      effective
    rescue ArgumentError
      raise CatalogTransitionInvalid.new(reason_code: "plan_effective_at_invalid"), cause: nil
    end

    def audit_rejection(plan_key, version, authorization, error)
      return unless Shared::Public.application_uuid?(authorization&.actor_user_id)

      record_id = PlanVersion.joins(:plan).find_by(plans: { key: plan_key }, version: version)&.id
      Auditing::Public.record!(
        actor_user_id: authorization.actor_user_id,
        action: "plan.version_publish_rejected",
        target_type: "PlanVersion",
        target_id: record_id,
        result: "denied",
        metadata: {
          operation: "publish",
          reason_code: error.respond_to?(:reason_code) ? error.reason_code : "plan_publish_failed"
        }
      )
    end
  end
end
