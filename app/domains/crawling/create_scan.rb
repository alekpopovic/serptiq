# frozen_string_literal: true

module Crawling
  class CreateScan
    def initialize(clock: -> { Time.current }, id_generator: -> { SecureRandom.uuid }, access: ScanAccess.new)
      @clock = clock
      @id_generator = id_generator
      @access = access
    end

    def call(actor_membership:, project_id:, property_id:, environment_id:, scan_type:,
      settings_snapshot:, entitlement_snapshot:, engine_version:, rule_set_version:,
      configuration_version: 1, release_id: nil, baseline_scan_id: nil)
      context = @access.call(
        actor_membership: actor_membership,
        project_id: project_id,
        property_id: property_id,
        environment_id: environment_id,
        permission_key: "scans.run",
        active_required: true
      )
      settings = ScanSnapshot.new(value: settings_snapshot)
      entitlements = ScanSnapshot.new(value: entitlement_snapshot)
      now = @clock.call
      scan = nil
      outbox = nil

      Scan.transaction do
        baseline = load_baseline!(context, baseline_scan_id)
        scan = Scan.create!(
          id: @id_generator.call,
          organization_id: context.project.organization_id,
          project_id: context.project.id,
          property_id: context.property.id,
          environment_id: context.environment.id,
          scan_type: scan_type,
          initiator_type: "membership",
          initiated_by_membership_id: context.actor_membership_id,
          status: "requested",
          settings_snapshot: settings.value,
          settings_digest: settings.digest,
          entitlement_snapshot: entitlements.value,
          entitlement_digest: entitlements.digest,
          engine_version: engine_version,
          rule_set_version: rule_set_version,
          configuration_version: configuration_version,
          release_id: release_id,
          baseline_scan_id: baseline&.id,
          requested_at: now,
          progress_sequence: 1
        )
        _event, outbox = ScanLifecycleRecord.record!(
          scan: scan,
          event_type: "scan.requested",
          from_status: nil,
          actor_membership_id: context.actor_membership_id,
          command: "request",
          occurred_at: now
        )
      end
      ScanLifecycleRecord.enqueue(outbox)
      scan
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "scan_baseline_unavailable"), cause: nil
    rescue ArgumentError => error
      raise Invalid.new(
        field_errors: { snapshot: [ error.message ] }, reason_code: "scan_snapshot_invalid"
      ), cause: nil
    end

    private

    def load_baseline!(context, baseline_scan_id)
      return unless baseline_scan_id

      Scan.where(
        organization_id: context.project.organization_id,
        project_id: context.project.id,
        property_id: context.property.id,
        environment_id: context.environment.id
      ).where(status: %w[completed partially_completed]).find(baseline_scan_id)
    end
  end
end
