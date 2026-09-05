# frozen_string_literal: true

require "digest"

module Crawling
  class DiscoverFrontier
    MAXIMUM_BATCH_SIZE = 500
    ACTIVE_SCAN_STATUSES = %w[queued running].freeze

    def initialize(clock: -> { Time.current }, progress: FrontierProgressRecorder.new)
      @clock = clock
      @progress = progress
    end

    def call(organization_id:, scan_id:, entries:)
      normalized = normalize_entries(entries)
      scan = exact_active_scan!(organization_id, scan_id)
      validate_parents!(scan, normalized)
      outbox = nil
      rows = nil
      inserted_count = 0
      CrawlUrl.transaction do
        now = @clock.call
        result = CrawlUrl.insert_all(
          normalized.map { |entry| attributes_for(scan, entry, now) },
          unique_by: :index_crawl_urls_on_scan_url_identity,
          returning: %w[id normalized_url_digest]
        )
        promote_pending_entries!(scan, normalized, now)
        rows = load_and_verify!(scan, normalized)
        inserted_count = result.rows.length
        if inserted_count.positive?
          scan = Scan.lock.find_by!(organization_id: organization_id, id: scan_id)
          ensure_active_scan!(scan)
          outbox = @progress.call(
            scan: scan,
            deltas: {
              urls_discovered_count: inserted_count,
              urls_queued_count: inserted_count
            },
            operation_key: discovery_operation_key(result.rows),
            occurred_at: now
          )
        end
      end
      ScanLifecycleRecord.enqueue(outbox) if outbox
      FrontierDiscoveryResult.new(
        scan_id: scan.id,
        inserted_count: inserted_count,
        items: rows.sort_by(&:id)
      )
    rescue ActiveRecord::InvalidForeignKey, ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "frontier_scope_unavailable"), cause: nil
    end

    private

    def normalize_entries(entries)
      values = Array(entries)
      raise Invalid.new(
        field_errors: { entries: "Supply between 1 and #{MAXIMUM_BATCH_SIZE} frontier entries." },
        reason_code: "frontier_batch_invalid"
      ) unless values.length.between?(1, MAXIMUM_BATCH_SIZE)

      normalized = values.map { |entry| entry.is_a?(FrontierEntry) ? entry : FrontierEntry.new(**entry) }
      grouped = normalized.group_by(&:normalized_url_digest)
      if grouped.any? { |_digest, group| group.map(&:normalized_url).uniq.many? }
        raise Conflict.new(reason_code: "frontier_digest_collision")
      end
      grouped.values.map { |group| group.min_by { |entry| [ entry.depth, -entry.priority ] } }
    rescue ArgumentError, TypeError => error
      raise Invalid.new(
        field_errors: { entries: "Frontier entries must be bounded canonical HTTP(S) URLs." },
        reason_code: "frontier_batch_invalid"
      ), cause: error
    end

    def exact_active_scan!(organization_id, scan_id)
      scan = Scan.find_by!(organization_id: organization_id, id: scan_id)
      ensure_active_scan!(scan)
      scan
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "frontier_scope_unavailable"), cause: nil
    end

    def ensure_active_scan!(scan)
      raise Conflict.new(reason_code: "frontier_scan_state_invalid") unless
        scan.status.in?(ACTIVE_SCAN_STATUSES)
    end

    def validate_parents!(scan, entries)
      parent_ids = entries.filter_map(&:discovered_from_id).uniq
      return if parent_ids.empty?

      available = CrawlUrl.where(scan_id: scan.id, id: parent_ids).count
      raise AccessDenied.new(reason_code: "frontier_parent_unavailable") unless available == parent_ids.length
    end

    def attributes_for(scan, entry, now)
      {
        organization_id: scan.organization_id,
        project_id: scan.project_id,
        property_id: scan.property_id,
        environment_id: scan.environment_id,
        scan_id: scan.id,
        **entry.to_h,
        state: "pending",
        attempts: 0,
        maximum_attempts: settings.fetch(:crawler_frontier_max_attempts),
        next_attempt_at: now,
        created_at: now,
        updated_at: now
      }
    end

    def load_and_verify!(scan, entries)
      expected = entries.index_by(&:normalized_url_digest)
      rows = CrawlUrl.where(scan_id: scan.id, normalized_url_digest: expected.keys).to_a
      collision = rows.any? do |row|
        entry = expected.fetch(row.normalized_url_digest)
        row.normalized_url != entry.normalized_url ||
          row.normalization_version != entry.normalization_version
      end
      raise Conflict.new(reason_code: "frontier_digest_collision") if collision || rows.length != expected.length

      rows
    end

    def promote_pending_entries!(scan, entries, now)
      rows = entries.map { |entry| attributes_for(scan, entry, now) }
      CrawlUrl.upsert_all(
        rows,
        unique_by: :index_crawl_urls_on_scan_url_identity,
        on_duplicate: Arel.sql(
          "depth = CASE WHEN crawl_urls.state = 'pending' " \
            "THEN LEAST(crawl_urls.depth, EXCLUDED.depth) ELSE crawl_urls.depth END, " \
            "priority = CASE WHEN crawl_urls.state = 'pending' " \
            "THEN GREATEST(crawl_urls.priority, EXCLUDED.priority) ELSE crawl_urls.priority END, " \
            "updated_at = CASE WHEN crawl_urls.state = 'pending' " \
            "THEN GREATEST(crawl_urls.updated_at, EXCLUDED.updated_at) ELSE crawl_urls.updated_at END"
        )
      )
    end

    def discovery_operation_key(returned_rows)
      ids = returned_rows.map { |row| row.first.to_i }.sort.join(":")
      "discover:#{Digest::SHA256.hexdigest(ids)}"
    end

    def settings
      Rails.application.config.x.searchops
    end
  end
end
