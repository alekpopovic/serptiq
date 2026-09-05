# frozen_string_literal: true

module Crawling
  RenderMetricsSnapshot = Data.define(
    :pending_count, :processing_count, :stale_count, :completed_count,
    :failed_count, :canceled_count, :average_duration_ms
  )

  class RenderMetrics
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(organization_id: nil)
      relation = PageRender.all
      relation = relation.where(organization_id: organization_id) if organization_id
      counts = relation.group(:state).count
      RenderMetricsSnapshot.new(
        pending_count: counts.fetch("pending", 0),
        processing_count: counts.fetch("processing", 0),
        stale_count: relation.where(state: "processing", lease_expires_at: ..@clock.call).count,
        completed_count: counts.fetch("completed", 0),
        failed_count: counts.fetch("failed", 0),
        canceled_count: counts.fetch("canceled", 0),
        average_duration_ms: relation.where(state: "completed").average(:duration_ms)&.round || 0
      )
    end
  end
end
