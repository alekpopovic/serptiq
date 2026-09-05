# frozen_string_literal: true

require "securerandom"

module Crawling
  class AcquireFetchPermit
    ACTIVE_SCAN_STATUSES = %w[queued running].freeze

    def initialize(clock: -> { Time.current }, limits: ResolvePressureLimits.new,
      state_keys: PressureStateKey.new,
      emitter: ->(name, **attributes) { Shared::Public.emit_structured_event(name, **attributes) })
      @clock = clock
      @limits = limits
      @state_keys = state_keys
      @emitter = emitter
    end

    def call(context:, url:)
      raise ArgumentError, "Crawling::FetchPermitContext is required" unless
        context.is_a?(FetchPermitContext)

      host_key = HostKey.new(url: url)
      decision = nil
      FetchPermit.transaction do
        PressureLock.acquire!
        now = @clock.call
        scan, item = lock_context!(context, now)
        limits = @limits.call(scan: scan, at: now)
        decision = cancellation_decision(scan, limits)
        next if decision

        expire_stale_frontier_permit!(item.id, now)
        if (existing = FetchPermit.active_at(now).find_by(crawl_url_id: item.id))
          decision = bounded_throttle(
            scan, limits, "frontier_permit_active", "scan", existing.expires_at, now
          )
          next
        end
        states = lock_states(scan, host_key, now)
        decision = availability_decision(scan, states, limits, now)
        next if decision

        token = SecureRandom.hex(32)
        expires_at = [ now + limits.permit_duration.seconds, limits.scan_deadline ].min
        if expires_at <= now
          decision = decide(scan, limits, "exhausted", "scan_deadline_exceeded", "scan", nil, now)
          next
        end

        advance_rate_clocks!(states, limits, now)
        permit = FetchPermit.create!(
          organization_id: scan.organization_id,
          project_id: scan.project_id,
          property_id: scan.property_id,
          environment_id: scan.environment_id,
          scan_id: scan.id,
          crawl_url_id: item.id,
          host_key_digest: host_key.digest,
          worker_id: context.worker_id,
          permit_token_digest: Digest::SHA256.hexdigest(token),
          state: "active",
          acquired_at: now,
          expires_at: expires_at
        )
        clear_throttle!(scan)
        decision = FetchPermitDecision.new(
          state: "acquired",
          reason_code: nil,
          scope: nil,
          retry_at: nil,
          permit: FetchPermitGrant.new(
            id: permit.id,
            token: token,
            host_key_digest: host_key.digest,
            expires_at: expires_at
          ),
          limits: limits
        )
      end
      emit(decision)
      decision
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "fetch_permit_scope_unavailable"), cause: nil
    end

    private

    def lock_context!(context, now)
      scan = Scan.lock.find_by!(organization_id: context.organization_id, id: context.scan_id)
      item = CrawlUrl.lock.find_by!(
        organization_id: context.organization_id,
        scan_id: scan.id,
        id: context.crawl_url_id
      )
      valid = item.leased? && item.leased_by == context.worker_id &&
        item.lease_expires_at > now && item.lease_token_matches?(context.frontier_lease_token)
      raise Conflict.new(reason_code: "frontier_lease_lost") unless valid

      [ scan, item ]
    end

    def cancellation_decision(scan, limits)
      return if scan.status.in?(ACTIVE_SCAN_STATUSES)

      reason = scan.status == "cancel_requested" || scan.terminal? ? "scan_canceled" : "scan_not_running"
      FetchPermitDecision.new(
        state: "canceled",
        reason_code: reason,
        scope: "scan",
        retry_at: nil,
        permit: nil,
        limits: limits
      )
    end

    def expire_stale_frontier_permit!(crawl_url_id, now)
      FetchPermit.where(crawl_url_id: crawl_url_id).stale_at(now).update_all(
        state: "expired",
        released_at: now,
        release_outcome: "expired",
        failure_category: "permit_expired",
        updated_at: now
      )
    end

    def lock_states(scan, host_key, now)
      definitions = {
        global: @state_keys.global,
        organization: @state_keys.organization(scan),
        scan: @state_keys.scan(scan),
        host: @state_keys.host(host_key)
      }
      definitions.transform_values do |attributes|
        state = PressureState.find_or_create_by!(attributes) { |record| record.next_fetch_at = now }
        state.lock!
        state
      end.freeze
    end

    def availability_decision(scan, states, limits, now)
      return decide(scan, limits, "throttled", "global_disabled", "global", nil, now) if
        states.fetch(:global).disabled?
      return decide(scan, limits, "throttled", "host_disabled", "host", nil, now) if
        states.fetch(:host).disabled?
      return decide(scan, limits, "exhausted", "scan_deadline_exceeded", "scan", nil, now) if
        now >= limits.scan_deadline

      concurrency_checks(scan, states, limits, now).each do |scope, count, limit, relation|
        next if count < limit

        retry_at = relation.minimum(:expires_at) || now + throttle_poll_interval.seconds
        return bounded_throttle(scan, limits, "#{scope}_concurrency", scope, retry_at, now)
      end

      wait = rate_wait(states, now)
      return unless wait

      bounded_throttle(scan, limits, wait.fetch(:reason), wait.fetch(:scope), wait.fetch(:retry_at), now)
    end

    def concurrency_checks(scan, states, limits, now)
      active = FetchPermit.active_at(now)
      [
        [ "global", active.count, limits.global_concurrency, active ],
        [ "organization", active.where(organization_id: scan.organization_id).count,
          limits.organization_concurrency, active.where(organization_id: scan.organization_id) ],
        [ "scan", active.where(scan_id: scan.id).count,
          limits.scan_concurrency, active.where(scan_id: scan.id) ],
        [ "host", active.where(host_key_digest: states.fetch(:host).host_key_digest).count,
          limits.host_concurrency, active.where(host_key_digest: states.fetch(:host).host_key_digest) ]
      ]
    end

    def rate_wait(states, now)
      candidates = [
        [ "global_rate", "global", states.fetch(:global).next_fetch_at ],
        [ "organization_rate", "organization", states.fetch(:organization).next_fetch_at ],
        [ "scan_rate", "scan", states.fetch(:scan).next_fetch_at ],
        [ "host_rate", "host", states.fetch(:host).next_fetch_at ],
        [ "host_backoff", "host", states.fetch(:host).backoff_until ]
      ].filter { |_reason, _scope, at| at && at > now }
      return if candidates.empty?

      reason, scope, retry_at = candidates.max_by { |_candidate_reason, _candidate_scope, at| at }
      { reason: reason, scope: scope, retry_at: retry_at }
    end

    def bounded_throttle(scan, limits, reason, scope, retry_at, now)
      if retry_at >= limits.scan_deadline
        decide(scan, limits, "exhausted", "scan_deadline_exceeded", "scan", nil, now)
      else
        decide(scan, limits, "throttled", reason, scope, retry_at, now)
      end
    end

    def decide(scan, limits, state, reason, scope, retry_at, now)
      observe_throttle!(scan, reason, retry_at, now) if state == "throttled"
      FetchPermitDecision.new(
        state: state,
        reason_code: reason,
        scope: scope,
        retry_at: retry_at,
        permit: nil,
        limits: limits
      )
    end

    def advance_rate_clocks!(states, limits, now)
      {
        global: limits.global_rate,
        organization: limits.organization_rate,
        scan: limits.scan_rate,
        host: limits.host_rate
      }.each do |scope, rate|
        states.fetch(scope).update!(next_fetch_at: now + (1.0 / rate).seconds)
      end
    end

    def observe_throttle!(scan, reason, retry_at, now)
      scan.update!(throttled_at: now, throttle_reason: reason, throttle_until: retry_at)
    end

    def clear_throttle!(scan)
      return unless scan.throttled_at

      scan.update!(throttled_at: nil, throttle_reason: nil, throttle_until: nil)
    end

    def throttle_poll_interval
      Rails.application.config.x.searchops.fetch(:crawler_throttle_poll_interval)
    end

    def emit(decision)
      @emitter.call(
        "crawler.fetch_pressure",
        severity: decision.acquired? ? :info : :warn,
        outcome: decision.acquired? ? "succeeded" : (decision.throttled? ? "retrying" : "denied"),
        operation: "acquire",
        reason_code: decision.reason_code
      )
    rescue StandardError => error
      Shared::Public.report_observability_failure(error, event_name: "crawler.fetch_pressure")
    end
  end
end
