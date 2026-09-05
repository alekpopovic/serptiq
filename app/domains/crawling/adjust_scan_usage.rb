# frozen_string_literal: true

module Crawling
  class AdjustScanUsage
    def call(organization_id:, scan_id:, usage_event_id:, actor_membership:, authorization:,
      idempotency_key:, quantity:, reason_code:, occurred_at: Time.current, metadata: {})
      scan = Scan.find_by(id: scan_id, organization_id: organization_id)
      raise AccessDenied.new(reason_code: "scan_usage_adjustment_unavailable") unless scan
      event = Usage::Public.source_event(
        event_id: usage_event_id,
        organization_id: organization_id,
        source_type: "Scan",
        source_id: scan.id
      )

      Usage::Public.correct_with_authority(
        organization_id: organization_id,
        event_id: event.id,
        idempotency_key: idempotency_key,
        quantity: quantity,
        reason_code: reason_code,
        occurred_at: occurred_at,
        actor_membership: actor_membership,
        authorization: authorization,
        metadata: metadata.merge("scan_id" => scan.id)
      )
    rescue Usage::Public::Invalid
      raise AccessDenied.new(reason_code: "scan_usage_adjustment_unavailable"), cause: nil
    end
  end
end
