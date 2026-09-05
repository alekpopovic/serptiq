# frozen_string_literal: true

module Crawling
  class SetEmergencyControl
    SCOPES = %w[global host].freeze

    def initialize(clock: -> { Time.current }, policy: OperatorPolicy.new,
      state_keys: PressureStateKey.new,
      emitter: ->(name, **attributes) { Shared::Public.emit_structured_event(name, **attributes) })
      @clock = clock
      @policy = policy
      @state_keys = state_keys
      @emitter = emitter
    end

    def call(user:, scope:, disabled:, reason_code:, url: nil)
      actor = @policy.authorize!(user: user)
      normalized_scope = scope.to_s
      reason = reason_code.to_s
      valid = SCOPES.include?(normalized_scope) && [ true, false ].include?(disabled) &&
        CrawlUrl::FAILURE_PATTERN.match?(reason)
      raise ArgumentError, "emergency crawl control is invalid" unless valid

      key = normalized_scope == "global" ? @state_keys.global : @state_keys.host(HostKey.new(url: url))
      state = nil
      changed = false
      PressureState.transaction do
        PressureLock.acquire!
        now = @clock.call
        state = PressureState.find_or_create_by!(key) { |record| record.next_fetch_at = now }
        state.lock!
        changed = disabled ? disable!(state, actor, reason, now) : resume!(state)
        Auditing::Public.record!(
          action: "crawler.emergency_control_changed",
          target_type: "CrawlPressureState",
          target_id: state.id,
          actor_user_id: actor.id,
          result: changed ? "succeeded" : "ignored",
          metadata: {
            operation: disabled ? "disable" : "resume",
            scope_type: normalized_scope,
            reason_code: reason
          },
          occurred_at: now
        )
      end
      emit(disabled, normalized_scope, changed, reason)
      state
    rescue OperatorAccessDenied => error
      audit_denial(user, scope, disabled, error.reason_code)
      raise
    end

    private

    def disable!(state, actor, reason, now)
      return false if state.disabled? && state.disabled_reason == reason

      state.update!(disabled_at: now, disabled_by_user_id: actor.id, disabled_reason: reason)
      true
    end

    def resume!(state)
      return false unless state.disabled?

      state.update!(disabled_at: nil, disabled_by_user_id: nil, disabled_reason: nil)
      true
    end

    def audit_denial(user, scope, disabled, reason)
      safe_scope = SCOPES.include?(scope.to_s) ? scope.to_s : "invalid"
      Auditing::Public.record!(
        action: "crawler.emergency_control_rejected",
        target_type: "CrawlPressureState",
        actor_user_id: user&.id,
        result: "denied",
        metadata: {
          operation: disabled == true ? "disable" : "resume",
          scope_type: safe_scope,
          reason_code: reason
        }
      )
    rescue StandardError
      nil
    end

    def emit(disabled, scope, changed, reason)
      @emitter.call(
        "crawler.emergency_control",
        severity: disabled ? :warn : :info,
        outcome: changed ? "succeeded" : "ignored",
        operation: disabled ? "disable" : "resume",
        scope_type: scope,
        reason_code: reason
      )
    rescue StandardError => error
      Shared::Public.report_observability_failure(error, event_name: "crawler.emergency_control")
    end
  end
end
