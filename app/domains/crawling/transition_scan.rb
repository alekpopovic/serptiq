# frozen_string_literal: true

module Crawling
  class TransitionScan
    EVENT_TYPES = {
      "admit" => "scan.admitted",
      "queue" => "scan.queued",
      "start" => "scan.started",
      "acknowledge_cancel" => "scan.canceled",
      "complete" => "scan.completed",
      "complete_partially" => "scan.partially_completed",
      "fail" => "scan.failed"
    }.freeze

    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(organization_id:, scan_id:, command:, failure_category: nil)
      action = command.to_s
      raise Conflict.new(reason_code: "scan_command_invalid") unless EVENT_TYPES.key?(action)

      scan = nil
      outbox = nil
      Scan.transaction do
        scan = Scan.lock.find_by!(organization_id: organization_id, id: scan_id)
        target = ScanTransitionMatrix.target(status: scan.status, command: action)
        return scan if idempotent_target?(scan, action, failure_category)
        raise Conflict.new(reason_code: "scan_transition_invalid") unless target

        validate_failure_category!(action, failure_category)
        from_status = scan.status
        now = @clock.call
        scan.assign_attributes(transition_attributes(action, target, now, failure_category))
        scan.progress_sequence += 1
        scan.save!
        _event, outbox = ScanLifecycleRecord.record!(
          scan: scan,
          event_type: EVENT_TYPES.fetch(action),
          from_status: from_status,
          actor_membership_id: nil,
          command: action,
          occurred_at: now
        )
      end
      ScanLifecycleRecord.enqueue(outbox)
      scan
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "scan_scope_unavailable"), cause: nil
    end

    private

    def idempotent_target?(scan, command, failure_category)
      if command == "fail"
        return scan.status == "failed" && scan.failure_category == failure_category
      end

      target = EVENT_TYPES.fetch(command).delete_prefix("scan.")
      target = "running" if command == "start"
      target = "canceled" if command == "acknowledge_cancel"
      target = "partially_completed" if command == "complete_partially"
      scan.status == target
    end

    def validate_failure_category!(command, category)
      valid = if command == "fail"
        Scan::FAILURE_CATEGORY_PATTERN.match?(category.to_s)
      else
        category.nil?
      end
      raise Conflict.new(reason_code: "scan_failure_category_invalid") unless valid
    end

    def transition_attributes(command, target, now, failure_category)
      attributes = { status: target }
      case command
      when "admit" then attributes[:admitted_at] = now
      when "queue" then attributes[:queued_at] = now
      when "start" then attributes[:started_at] = now
      when "acknowledge_cancel"
        attributes.merge!(canceled_at: now, urls_queued_count: 0, urls_running_count: 0)
      when "complete", "complete_partially"
        attributes.merge!(completed_at: now, urls_queued_count: 0, urls_running_count: 0)
      when "fail"
        attributes.merge!(
          failed_at: now, failure_category: failure_category,
          urls_queued_count: 0, urls_running_count: 0
        )
      end
      attributes.merge!(throttled_at: nil, throttle_reason: nil, throttle_until: nil) if
        target.in?(Scan::TERMINAL_STATUSES)
      attributes
    end
  end
end
