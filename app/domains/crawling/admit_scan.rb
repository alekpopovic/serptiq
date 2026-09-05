# frozen_string_literal: true

module Crawling
  class AdmitScan
    ENGINE_VERSION = "crawler-1.0.0"
    RULE_SET_VERSION = "rules-1.0.0"
    CONFIGURATION_VERSION = 1

    def initialize(clock: -> { Time.current }, access: ScanAccess.new,
      policy_resolver: ResolveAdmissionPolicy.new, limit_resolver: ResolveConcurrentScanLimits.new,
      capacity: ScanCapacity.new, preflight: PreflightOrigin.new,
      billing_period_resolver: ResolveAdmissionBillingPeriod.new,
      verification_resolver: ->(**attributes) { Verification::Public.fresh_verification(**attributes) },
      dispatch_enqueuer: nil)
      @clock = clock
      @access = access
      @policy_resolver = policy_resolver
      @limit_resolver = limit_resolver
      @capacity = capacity
      @preflight = preflight
      @billing_period_resolver = billing_period_resolver
      @verification_resolver = verification_resolver
      @dispatch_enqueuer = dispatch_enqueuer || EnqueueScanDispatch.new(clock: clock)
    end

    def call(actor_membership:, request:)
      validate_request!(request)
      now = @clock.call
      context = authorized_context(actor_membership, request)
      initial_access = authorize_capability!(context, actor_membership)
      existing = existing_scan(context, request)
      return recover_dispatch(existing) if existing

      policy = @policy_resolver.call(
        environment: context.environment,
        verified_owner: context.property.verified?,
        at: now
      )
      workload = verification_workload(policy)
      verification = verified_origin!(context, workload, now)
      preflight = @preflight.call(environment: context.environment)
      concurrency = @limit_resolver.call(
        organization_id: context.project.organization_id,
        at: now
      )
      billing_period = @billing_period_resolver.call(
        organization_id: context.project.organization_id,
        at: now
      )
      scan, outboxes, created = transactionally_admit(
        context: context,
        actor_membership: actor_membership,
        request: request,
        initial_access: initial_access,
        policy: policy,
        verification: verification,
        workload: workload,
        preflight: preflight,
        concurrency: concurrency,
        billing_period: billing_period,
        now: now
      )
      outboxes.each { |outbox| ScanLifecycleRecord.enqueue(outbox) }
      @dispatch_enqueuer.call(organization_id: scan.organization_id, scan_id: scan.id) if created
      scan
    end

    private

    def validate_request!(request)
      raise ArgumentError, "Crawling::AdmissionRequest is required" unless request.is_a?(AdmissionRequest)
    end

    def authorized_context(actor_membership, request)
      @access.call(
        actor_membership: actor_membership,
        project_id: request.project_id,
        property_id: request.property_id,
        environment_id: request.environment_id,
        permission_key: "scans.run",
        active_required: true
      )
    end

    def authorize_capability!(context, actor_membership)
      Authorization::Public.authorize_access!(Authorization::Public::AccessRequest.new(
        actor_membership: actor_membership,
        organization: context.project.organization_id,
        permission_key: "scans.run",
        project: context.project,
        property: context.property,
        resource: resource_context(context),
        entitlement_key: "crawl.manual"
      ))
    end

    def resource_context(context)
      Authorization::Public::ResourceContext.new(
        id: context.environment.id,
        type: "property_environment",
        organization_id: context.project.organization_id,
        scope_type: "Property",
        scope_id: context.property.id,
        available: context.project.active? && context.property.active? && context.environment.active?
      )
    end

    def existing_scan(context, request)
      scan = Scan.find_by(
        organization_id: context.project.organization_id,
        request_idempotency_digest: request.idempotency_digest
      )
      verify_replay!(scan, request) if scan
      scan
    end

    def verify_replay!(scan, request)
      matches = ActiveSupport::SecurityUtils.secure_compare(
        scan.request_checksum.to_s,
        request.checksum
      )
      raise AdmissionIdempotencyConflict unless matches
    end

    def recover_dispatch(scan)
      @dispatch_enqueuer.call(organization_id: scan.organization_id, scan_id: scan.id) if
        scan.status == "admitted" && scan.dispatch_enqueued_at.nil?
      scan
    end

    def verification_workload(policy)
      return "render" if policy.configuration.max_rendered_pages.positive?
      return "high_volume" if policy.configuration.max_urls > 500

      "standard"
    end

    def verified_origin!(context, workload, now)
      verification = @verification_resolver.call(
        organization_id: context.project.organization_id,
        project_id: context.project.id,
        property_id: context.property.id,
        environment_id: context.environment.id,
        workload: workload,
        at: now
      )
      raise VerificationRequired unless verification

      verification
    end

    def transactionally_admit(**attributes)
      result = nil
      Scan.transaction do
        @capacity.lock!(
          organization_id: attributes.fetch(:context).project.organization_id,
          project_id: attributes.fetch(:context).project.id
        )
        replay = existing_scan(attributes.fetch(:context), attributes.fetch(:request))
        if replay
          result = [ replay, [], false ]
          next
        end
        @capacity.check!(
          organization_id: attributes.fetch(:context).project.organization_id,
          project_id: attributes.fetch(:context).project.id,
          limits: attributes.fetch(:concurrency)
        )

        window = Usage::Public.resolve_window(
          organization_id: attributes.fetch(:context).project.organization_id,
          meter_key: "crawl.http_fetch",
          at: attributes.fetch(:now),
          billing_period: attributes.fetch(:billing_period)
        )
        access_request = metered_access_request(window: window, **attributes)
        result = Authorization::Public.with_access(access_request) do |decision|
          create_admitted_scan(reservation: decision.reservation, **attributes)
        end
      end
      result
    rescue ActiveRecord::RecordNotUnique
      replay = existing_scan(attributes.fetch(:context), attributes.fetch(:request))
      return [ replay, [], false ] if replay

      raise
    end

    def metered_access_request(window:, **attributes)
      context = attributes.fetch(:context)
      request = attributes.fetch(:request)
      now = attributes.fetch(:now)
      estimate = attributes.fetch(:policy).estimate
      Authorization::Public::AccessRequest.new(
        actor_membership: attributes.fetch(:actor_membership),
        organization: context.project.organization_id,
        permission_key: "scans.run",
        project: context.project,
        property: context.property,
        resource: resource_context(context),
        entitlement_key: "crawl.manual",
        metered_quantity: estimate.maximum_credits / estimate.http_weight,
        idempotency_key: "scan-admission:#{request.idempotency_digest}",
        usage_window: window,
        usage_source: Usage::Public::SourceReference.new(
          organization_id: context.project.organization_id,
          type: "Scan",
          id: request.scan_id(organization_id: context.project.organization_id)
        ),
        reservation_expires_at: reservation_expiry(window, now),
        evaluated_at: now
      )
    end

    def reservation_expiry(window, now)
      [ window.ends_at, now.beginning_of_hour + 2.hours ].min
    end

    def create_admitted_scan(reservation:, **attributes)
      context = attributes.fetch(:context)
      request = attributes.fetch(:request)
      now = attributes.fetch(:now)
      policy = attributes.fetch(:policy)
      verification = attributes.fetch(:verification)
      preflight = attributes.fetch(:preflight)
      actor_id = context.actor_membership_id
      baseline = load_baseline!(context, request.baseline_scan_id)
      settings = ScanSnapshot.new(value: policy.configuration.as_json)
      entitlements = ScanSnapshot.new(value: entitlement_snapshot(
        initial_access: attributes.fetch(:initial_access),
        concurrency: attributes.fetch(:concurrency),
        policy: policy,
        verification: verification,
        workload: attributes.fetch(:workload)
      ))
      scan = Scan.create!(
        id: request.scan_id(organization_id: context.project.organization_id),
        organization_id: context.project.organization_id,
        project_id: context.project.id,
        property_id: context.property.id,
        environment_id: context.environment.id,
        scan_type: request.scan_type,
        initiator_type: request.initiator_type,
        initiated_by_membership_id: request.source == "manual" ? actor_id : nil,
        status: "requested",
        settings_snapshot: settings.value,
        settings_digest: settings.digest,
        entitlement_snapshot: entitlements.value,
        entitlement_digest: entitlements.digest,
        engine_version: ENGINE_VERSION,
        rule_set_version: RULE_SET_VERSION,
        configuration_version: CONFIGURATION_VERSION,
        release_id: request.release_id,
        baseline_scan_id: baseline&.id,
        request_source: request.source,
        request_idempotency_digest: request.idempotency_digest,
        request_checksum: request.checksum,
        admission_version: 1,
        usage_quota_reservation_id: reservation.id,
        domain_verification_id: verification.id,
        preflight_checked_at: preflight.checked_at,
        preflight_status_code: preflight.status_code,
        preflight_destination_digest: preflight.destination_digest,
        credit_estimate: policy.estimate.maximum_credits,
        requested_at: now,
        progress_sequence: 1
      )
      outboxes = []
      _event, outbox = ScanLifecycleRecord.record!(
        scan: scan,
        event_type: "scan.requested",
        from_status: nil,
        actor_membership_id: actor_id,
        command: "request",
        occurred_at: now,
        idempotency_source: "scan.requested:#{scan.id}:#{request.idempotency_digest}"
      )
      outboxes << outbox
      admitted_at = @clock.call
      scan.update!(status: "admitted", admitted_at: admitted_at, progress_sequence: 2)
      _event, outbox = ScanLifecycleRecord.record!(
        scan: scan,
        event_type: "scan.admitted",
        from_status: "requested",
        actor_membership_id: actor_id,
        command: "admit",
        occurred_at: admitted_at,
        idempotency_source: "scan.admitted:#{scan.id}:#{request.idempotency_digest}"
      )
      outboxes << outbox
      snapshot_policy!(scan, policy, settings, now)
      [ scan, outboxes, true ]
    end

    def entitlement_snapshot(initial_access:, concurrency:, policy:, verification:, workload:)
      {
        "crawl.manual" => {
          "state" => initial_access.entitlement.state,
          "provenance" => initial_access.entitlement.provenance
        },
        "crawl.concurrent_scans" => {
          "organization" => concurrency.organization,
          "project" => concurrency.project,
          "global" => concurrency.global,
          "provenance" => concurrency.provenance
        },
        "credit_estimate" => {
          "http_pages" => policy.estimate.http_pages,
          "rendered_pages" => policy.estimate.rendered_pages,
          "http_weight" => policy.estimate.http_weight.to_s("F"),
          "rendered_weight" => policy.estimate.rendered_weight.to_s("F"),
          "maximum_credits" => policy.estimate.maximum_credits.to_s("F")
        },
        "verification" => {
          "method" => verification.method,
          "verified_at" => verification.verified_at.utc.iso8601(6),
          "workload" => workload
        },
        "policy_limits" => policy.limits.provenance
      }
    end

    def snapshot_policy!(scan, policy, settings, now)
      return unless policy.source_version

      PolicySnapshot.create!(
        scan_id: scan.id,
        organization_id: scan.organization_id,
        project_id: scan.project_id,
        property_id: scan.property_id,
        environment_id: scan.environment_id,
        crawl_policy_version_id: policy.source_version.id,
        policy_version: policy.policy_version,
        configuration: settings.value,
        configuration_digest: settings.digest,
        created_at: now
      )
    end

    def load_baseline!(context, baseline_scan_id)
      return unless baseline_scan_id

      Scan.where(
        organization_id: context.project.organization_id,
        project_id: context.project.id,
        property_id: context.property.id,
        environment_id: context.environment.id,
        status: %w[completed partially_completed]
      ).find(baseline_scan_id)
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "scan_baseline_unavailable"), cause: nil
    end
  end
end
