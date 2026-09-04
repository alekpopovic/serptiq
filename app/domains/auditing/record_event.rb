# frozen_string_literal: true

module Auditing
  class RecordEvent
    def initialize(clock: -> { Time.current }, sanitizer: MetadataSanitizer.new)
      @clock = clock
      @sanitizer = sanitizer
    end

    def call(action:, target_type:, result:, organization_id: nil, actor_membership_id: nil,
      actor_user_id: nil, target_id: nil, metadata: {}, source_ip_digest: nil,
      user_agent_digest: nil, occurred_at: nil)
      now = occurred_at || @clock.call
      context = Shared::Public.observability_context
      AuditEvent.create!(
        organization_id: normalize_uuid(organization_id),
        actor_type: actor_type(actor_membership_id, actor_user_id),
        actor_membership_id: normalize_uuid(actor_membership_id),
        actor_user_id: normalize_uuid(actor_user_id),
        action: action,
        target_type: target_type,
        target_id: normalize_uuid(target_id),
        result: result,
        metadata: @sanitizer.call(metadata),
        request_id: context["request_id"],
        trace_id: context["trace_id"],
        job_id: context["job_id"],
        source_ip_digest: source_ip_digest,
        user_agent_digest: user_agent_digest,
        occurred_at: now,
        created_at: now
      )
    end

    private

    def actor_type(membership_id, user_id)
      return "Membership" if membership_id.present?
      return "User" if user_id.present?

      "System"
    end

    def normalize_uuid(value)
      candidate = value&.to_s
      Shared::Public.application_uuid?(candidate) ? candidate : nil
    end
  end
end
