# frozen_string_literal: true

require "digest"

module Crawling
  class SchedulePageRender
    def initialize(clock: -> { Time.current }, enqueuer: nil,
      settings: Rails.application.config.x.searchops)
      @clock = clock
      @settings = settings
      @enqueuer = enqueuer || lambda { |render|
        PageRenderJob.perform_later(
          organization_id: render.organization_id,
          scan_id: render.scan_id,
          page_render_id: render.id
        )
      }
    end

    def call(organization_id:, scan_id:, page_snapshot_id:)
      created = false
      render = PageRender.transaction do
        scan = Scan.lock.find_by!(organization_id: organization_id, id: scan_id)
        snapshot = PageSnapshot.includes(:fetch_result, :crawl_url, :page_fact).find_by!(
          organization_id: organization_id, scan_id: scan_id, id: page_snapshot_id
        )
        next PageRender.find_by(page_snapshot_id: snapshot.id) if PageRender.exists?(page_snapshot_id: snapshot.id)
        next unless eligible?(scan, snapshot)
        next unless PageRender.where(scan_id: scan.id).count < render_cap(scan)

        PageRender.create!(
          tenant_attributes(snapshot).merge(
            page_snapshot_id: snapshot.id,
            page_fact_id: snapshot.page_fact.id,
            state: "pending",
            maximum_attempts: 3,
            screenshot_enabled: @settings.fetch(:browser_screenshot_enabled),
            requested_url: snapshot.fetch_result.final_url,
            requested_url_digest: Digest::SHA256.hexdigest(snapshot.fetch_result.final_url),
            next_attempt_at: @clock.call
          )
        ).tap { created = true }
      end
      @enqueuer.call(render) if created
      render
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "page_render_scope_unavailable"), cause: nil
    rescue ActiveRecord::RecordNotUnique
      PageRender.find_by!(organization_id: organization_id, scan_id: scan_id, page_snapshot_id: page_snapshot_id)
    end

    private

    def eligible?(scan, snapshot)
      configuration = scan.settings_snapshot.to_h.stringify_keys
      percent = Integer(configuration.fetch("rendering_sample_percent", 0))
      return false unless scan.status == "running" && snapshot.completed? && snapshot.page_fact
      return false unless snapshot.page_fact.parse_status.in?(%w[parsed malformed])
      return false unless snapshot.fetch_result.outcome == "succeeded" && snapshot.fetch_result.sniffed_kind == "html"
      return false unless percent.positive? && render_cap(scan).positive?

      digest = Digest::SHA256.hexdigest("#{scan.id}:#{snapshot.crawl_url.normalized_url_digest}")
      digest.first(8).to_i(16) % 100 < percent
    rescue ArgumentError, TypeError
      false
    end

    def render_cap(scan)
      configured = Integer(scan.settings_snapshot.to_h.stringify_keys.fetch("max_rendered_pages", 0))
      planned = scan.entitlement_snapshot.dig("credit_estimate", "rendered_pages")
      planned ? [ configured, Integer(planned) ].min : configured
    rescue ArgumentError, TypeError
      0
    end

    def tenant_attributes(snapshot)
      {
        organization_id: snapshot.organization_id,
        project_id: snapshot.project_id,
        property_id: snapshot.property_id,
        environment_id: snapshot.environment_id,
        scan_id: snapshot.scan_id
      }
    end
  end
end
