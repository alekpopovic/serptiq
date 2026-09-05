# frozen_string_literal: true

require "time"

module Crawling
  class ReleaseFetchPermit
    TRANSIENT_HTTP_STATUSES = [ 429, 503 ].freeze
    TRANSIENT_FAILURES = %w[
      dns_failure timeout connect_timeout tls_timeout header_timeout body_timeout
      total_timeout tls_protocol transport_failure
    ].freeze

    def initialize(clock: -> { Time.current },
      emitter: ->(name, **attributes) { Shared::Public.emit_structured_event(name, **attributes) })
      @clock = clock
      @emitter = emitter
    end

    def call(organization_id:, permit_id:, permit_token:, outcome:, http_status_code: nil,
      failure_category: nil, retry_after: nil)
      result = normalize_result(outcome, http_status_code, failure_category)
      permit = nil
      FetchPermit.transaction do
        PressureLock.acquire!
        permit = FetchPermit.lock.find_by!(organization_id: organization_id, id: permit_id)
        raise Conflict.new(reason_code: "fetch_permit_token_invalid") unless
          permit.token_matches?(permit_token)
        if permit.state != "active"
          verify_replay!(permit, result)
          next
        end

        now = @clock.call
        permit.update!(
          state: "released",
          released_at: now,
          release_outcome: result.fetch(:outcome),
          http_status_code: result.fetch(:http_status_code),
          failure_category: result.fetch(:failure_category)
        )
        update_host_signal!(permit, result, retry_after, now)
      end
      emit(permit)
      permit
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "fetch_permit_scope_unavailable"), cause: nil
    end

    private

    def normalize_result(outcome, status, category)
      normalized_outcome = outcome.to_s
      raise ArgumentError, "fetch permit outcome is invalid" unless
        %w[succeeded http_error failed canceled].include?(normalized_outcome)
      normalized_status = status.nil? ? nil : Integer(status)
      raise ArgumentError, "HTTP status is invalid" unless
        normalized_status.nil? || normalized_status.between?(100, 599)
      normalized_category = category&.to_s
      raise ArgumentError, "failure category is invalid" unless
        normalized_category.nil? || CrawlUrl::FAILURE_PATTERN.match?(normalized_category)
      raise ArgumentError, "successful permit cannot have failure evidence" if
        normalized_outcome == "succeeded" && (normalized_category || (normalized_status && normalized_status >= 400))

      {
        outcome: normalized_outcome,
        http_status_code: normalized_status,
        failure_category: normalized_category
      }.freeze
    rescue ArgumentError
      raise
    rescue StandardError
      raise ArgumentError, "fetch permit result is invalid", cause: nil
    end

    def verify_replay!(permit, result)
      return permit if permit.state == "expired"
      matches = permit.release_outcome == result.fetch(:outcome) &&
        permit.http_status_code == result.fetch(:http_status_code) &&
        permit.failure_category == result.fetch(:failure_category)
      raise Conflict.new(reason_code: "fetch_permit_release_replay_conflict") unless matches
    end

    def update_host_signal!(permit, result, retry_after, now)
      state = PressureState.lock.find_by!(scope_type: "host", host_key_digest: permit.host_key_digest)
      if transient?(result)
        streak = [ state.failure_streak + 1, 20 ].min
        delay = backoff_delay(streak, retry_after, now)
        state.update!(
          failure_streak: streak,
          backoff_until: [ state.backoff_until, now + delay.seconds ].compact.max
        )
      elsif result.fetch(:outcome) == "succeeded" &&
          (state.backoff_until.nil? || state.backoff_until <= now)
        state.update!(failure_streak: 0, backoff_until: nil)
      end
    end

    def transient?(result)
      TRANSIENT_HTTP_STATUSES.include?(result.fetch(:http_status_code)) ||
        TRANSIENT_FAILURES.include?(result.fetch(:failure_category))
    end

    def backoff_delay(streak, retry_after, now)
      settings = Rails.application.config.x.searchops
      minimum = settings.fetch(:crawler_host_backoff_base)
      maximum = settings.fetch(:crawler_host_backoff_max)
      signaled = retry_after_delay(retry_after, now)
      candidate = signaled || minimum * (2**(streak - 1))
      candidate.clamp(minimum, maximum)
    end

    def retry_after_delay(value, now)
      candidate = value.to_s.strip
      return if candidate.blank? || candidate.bytesize > 128
      return Integer(candidate, 10) if candidate.match?(/\A[0-9]{1,10}\z/)

      [ Time.httpdate(candidate).utc - now.utc, 0 ].max
    rescue ArgumentError
      nil
    end

    def emit(permit)
      @emitter.call(
        "crawler.fetch_pressure",
        severity: permit.failure_category ? :warn : :info,
        outcome: permit.failure_category ? "failed" : "succeeded",
        operation: "release",
        reason_code: permit.failure_category,
        http_status: permit.http_status_code
      )
    rescue StandardError => error
      Shared::Public.report_observability_failure(error, event_name: "crawler.fetch_pressure")
    end
  end
end
