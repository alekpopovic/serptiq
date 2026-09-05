# frozen_string_literal: true

require "date"
require "digest"
require "time"

module Crawling
  class DiscoverSitemaps
    ACTIVE_SCAN_STATUSES = %w[queued running].freeze
    FRONTIER_BATCH_SIZE = DiscoverFrontier::MAXIMUM_BATCH_SIZE

    def initialize(retriever: RetrieveSitemap.new, decoder: nil, parser: nil,
      clock: -> { Time.current }, settings: nil)
      @retriever = retriever
      @decoder = decoder
      @parser = parser
      @clock = clock
      @settings = settings
    end

    def call(organization_id:, scan_id:, include_well_known: nil)
      scan = exact_scan!(organization_id, scan_id)
      environment = exact_environment!(scan)
      discovery = find_or_create_discovery(scan)
      return discovery if discovery.terminal?

      file_scope = sitemap_file_scope(environment)
      seed_files!(
        scan: scan,
        discovery: discovery,
        file_scope: file_scope,
        include_well_known: include_well_known
      )
      process_pending_files!(scan, discovery, environment, file_scope)
      finalize_discovery!(discovery)
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "sitemap_scope_unavailable"), cause: nil
    end

    private

    def exact_scan!(organization_id, scan_id)
      scan = Scan.find_by!(organization_id: organization_id, id: scan_id)
      raise Conflict.new(reason_code: "sitemap_scan_state_invalid") unless
        scan.status.in?(ACTIVE_SCAN_STATUSES)

      scan
    end

    def exact_environment!(scan)
      Properties::Public.environment_reference(
        organization_id: scan.organization_id,
        project_id: scan.project_id,
        property_id: scan.property_id,
        environment_id: scan.environment_id
      ) || raise(ActiveRecord::RecordNotFound)
    end

    def find_or_create_discovery(scan)
      SitemapDiscovery.find_or_create_by!(scan_id: scan.id) do |discovery|
        discovery.assign_attributes(
          organization_id: scan.organization_id,
          project_id: scan.project_id,
          property_id: scan.property_id,
          environment_id: scan.environment_id,
          status: "running",
          started_at: @clock.call
        )
      end.tap do |discovery|
        raise Conflict.new(reason_code: "sitemap_discovery_scope_conflict") unless
          discovery.organization_id == scan.organization_id &&
            discovery.project_id == scan.project_id &&
            discovery.property_id == scan.property_id &&
            discovery.environment_id == scan.environment_id
      end
    rescue ActiveRecord::RecordNotUnique
      retry
    end

    def seed_files!(scan:, discovery:, file_scope:, include_well_known:)
      candidates = configured_candidates(scan) + robots_candidates(scan)
      enabled = include_well_known.nil? ? setting(:crawler_sitemap_well_known_enabled) : include_well_known == true
      candidates << [ "#{file_scope.origin.origin}/sitemap.xml", "well_known" ] if enabled
      candidates.each do |url, source|
        add_file_candidate(
          scan: scan,
          discovery: discovery,
          file_scope: file_scope,
          url: url,
          source: source,
          parent: nil,
          index_depth: 0
        )
      end
    end

    def configured_candidates(scan)
      Array(scan.settings_snapshot.to_h["sitemap_urls"]).map { |url| [ url, "configured" ] }
    end

    def robots_candidates(scan)
      snapshot = RobotsSnapshot.find_by(organization_id: scan.organization_id, scan_id: scan.id)
      Array(snapshot&.sitemap_urls).map { |url| [ url, "robots" ] }
    end

    def sitemap_file_scope(environment)
      UrlScopePolicy.new(
        origin: environment.origin,
        max_depth: 10,
        query_handling: "all"
      )
    end

    def page_scope(scan)
      ResolveUrlScopePolicy.new.call(organization_id: scan.organization_id, scan_id: scan.id)
    end

    def add_file_candidate(scan:, discovery:, file_scope:, url:, source:, parent:, index_depth:)
      decision = file_scope.evaluate(url: url, depth: index_depth)
      unless decision.normalized_url
        add_discovery_warning!(discovery, "invalid_sitemap_candidate")
        return
      end

      normalized = decision.normalized_url
      digest = normalized.identity_digest
      existing = SitemapFile.find_by(scan_id: scan.id, url_digest: digest)
      return verify_file_identity!(existing, normalized.fetch_url) if existing

      if discovery.sitemap_files.count >= setting(:crawler_sitemap_max_documents)
        add_discovery_warning!(discovery, "document_limit")
        return
      end

      attributes = file_identity_attributes(
        scan: scan, discovery: discovery, parent: parent,
        url: normalized.fetch_url, url_digest: digest, source: source,
        index_depth: index_depth
      )
      attributes.merge!(status: "rejected", error_code: decision.reason_code) unless decision.allowed?
      SitemapFile.create!(attributes)
    rescue ActiveRecord::RecordNotUnique
      verify_file_identity!(SitemapFile.find_by!(scan_id: scan.id, url_digest: digest), normalized.fetch_url)
    end

    def file_identity_attributes(scan:, discovery:, parent:, url:, url_digest:, source:, index_depth:)
      {
        organization_id: scan.organization_id,
        project_id: scan.project_id,
        property_id: scan.property_id,
        environment_id: scan.environment_id,
        scan_id: scan.id,
        sitemap_discovery_id: discovery.id,
        parent_sitemap_file_id: parent&.id,
        url: url,
        url_digest: url_digest,
        source: source,
        index_depth: index_depth,
        status: "pending"
      }
    end

    def verify_file_identity!(file, expected_url)
      raise Conflict.new(reason_code: "sitemap_url_digest_collision") unless file.url == expected_url

      file
    end

    def process_pending_files!(scan, discovery, environment, file_scope)
      scope = page_scope(scan)
      loop do
        active = Scan.where(
          organization_id: scan.organization_id,
          id: scan.id,
          status: %w[queued running]
        ).exists?
        unless active
          SitemapFile.where(sitemap_discovery_id: discovery.id, status: "pending").update_all(
            status: "rejected", error_code: "scan_canceled", updated_at: @clock.call
          )
          add_discovery_warning!(discovery, "scan_canceled")
          break
        end

        file = SitemapFile.where(sitemap_discovery_id: discovery.id, status: "pending")
          .order(:index_depth, :created_at, :id).first
        break unless file

        if remaining_entry_budget(discovery).zero?
          reject_pending_file!(file, "scan_entry_limit")
          add_discovery_warning!(discovery, "scan_entry_limit")
          next
        end
        process_file!(scan, discovery, environment, file_scope, scope, file)
      end
    end

    def process_file!(scan, discovery, environment, file_scope, scope, file)
      retrieval = @retriever.call(origin: environment.origin, url: file.url)
      return persist_retrieval_failure!(file, retrieval) unless retrieval.status == "fetched"

      payload = decoder.call(body: retrieval.body)
      parsed = parser_for(discovery).call(xml: payload.xml)
      outcomes = process_entries!(scan, discovery, file_scope, scope, file, parsed.entries)
      warnings = bounded_warnings(parsed.warnings + outcomes.fetch(:warnings))
      status = parsed.malformed ? "malformed" : "fetched"
      file.update!(
        **retrieval_attributes(retrieval),
        status: status,
        document_kind: parsed.kind == "unknown" ? nil : parsed.kind,
        gzip: payload.gzip,
        compressed_bytes: payload.compressed_bytes,
        decompressed_bytes: payload.decompressed_bytes,
        parser_version: parsed.parser_version,
        entry_count: outcomes.fetch(:observed_count),
        entries_in_scope_count: outcomes.fetch(:in_scope_count),
        entries_out_of_scope_count: outcomes.fetch(:out_of_scope_count),
        entries_invalid_count: outcomes.fetch(:invalid_count),
        child_count: outcomes.fetch(:child_count),
        warning_count: warnings.length,
        warnings: warnings.map(&:as_json),
        error_code: parsed.malformed ? "parser_malformed" : nil
      )
    rescue SitemapPayloadError => error
      status = error.reason_code.include?("size_limit") ? "oversized" : "malformed"
      file.update!(
        **retrieval_attributes(retrieval),
        status: status,
        compressed_bytes: retrieval.body.bytesize,
        warning_count: 1,
        warnings: [ SitemapWarning.new(code: error.reason_code).as_json ],
        error_code: error.reason_code
      )
    end

    def persist_retrieval_failure!(file, retrieval)
      file.update!(
        **retrieval_attributes(retrieval),
        status: retrieval.status,
        error_code: retrieval.error_code,
        compressed_bytes: retrieval.body.bytesize
      )
    end

    def retrieval_attributes(retrieval)
      {
        http_status: retrieval.http_status,
        retrieved_at: retrieval.retrieved_at,
        artifact_sha256: retrieval.artifact_sha256,
        final_url: retrieval.final_url,
        redirect_count: retrieval.redirect_count,
        content_type: retrieval.content_type
      }
    end

    def reject_pending_file!(file, reason_code)
      file.update!(status: "rejected", error_code: reason_code)
    end

    def process_entries!(scan, discovery, file_scope, scope, file, parsed_entries)
      state = {
        observed_count: 0, in_scope_count: 0, out_of_scope_count: 0,
        invalid_count: 0, child_count: 0, warnings: [], rows: [], page_candidates: []
      }
      seen = {}
      parsed_entries.each do |entry|
        state[:observed_count] += 1
        decision = (entry.kind == "page" ? scope : file_scope).evaluate(
          url: entry.location,
          depth: entry.kind == "page" ? 0 : [ file.index_depth + 1, 10 ].min
        )
        unless decision.normalized_url
          state[:invalid_count] += 1
          warn_entry!(state, "invalid_location", entry.entry_index)
          next
        end

        if decision.allowed?
          state[:in_scope_count] += 1
        else
          state[:out_of_scope_count] += 1
        end
        warn_entry!(state, "invalid_lastmod", entry.entry_index) if
          lastmod_attributes(entry.lastmod)[:lastmod_precision] == "invalid"
        normalized = decision.normalized_url
        if seen.key?(normalized.identity_digest)
          raise Conflict.new(reason_code: "sitemap_entry_digest_collision") unless
            seen.fetch(normalized.identity_digest) == normalized.identity_url

          warn_entry!(state, "duplicate_location", entry.entry_index)
          next
        end
        seen[normalized.identity_digest] = normalized.identity_url

        row = entry_row(scan, file, entry, normalized, decision)
        if !decision.allowed?
          row[:relationship_status] = "out_of_scope"
          warn_entry!(state, "url_out_of_scope", entry.entry_index)
        elsif entry.kind == "page"
          state[:page_candidates] << [ row, frontier_entry(scan, entry.location) ]
        else
          relationship, child = sitemap_relationship(
            scan: scan,
            discovery: discovery,
            file_scope: file_scope,
            parent: file,
            entry: entry,
            normalized: normalized
          )
          row[:relationship_status] = relationship
          row[:child_sitemap_file_id] = child&.id
          state[:child_count] += 1 if relationship == "queued"
          warn_entry!(state, relationship_warning(relationship), entry.entry_index) if
            relationship_warning(relationship)
        end
        state[:rows] << row unless entry.kind == "page" && decision.allowed?
      end
      admit_page_candidates!(scan, state)
      persist_entry_rows!(state.fetch(:rows))
      state.except(:rows, :page_candidates)
    end

    def entry_row(scan, file, entry, normalized, decision)
      {
        organization_id: scan.organization_id,
        project_id: scan.project_id,
        property_id: scan.property_id,
        environment_id: scan.environment_id,
        scan_id: scan.id,
        sitemap_file_id: file.id,
        entry_index: entry.entry_index,
        entry_kind: entry.kind,
        location_url: normalized.identity_url,
        location_digest: normalized.identity_digest,
        normalization_version: normalized.normalization_version,
        scope_status: decision.allowed? ? "in_scope" : "out_of_scope",
        scope_reason: decision.reason_code,
        relationship_status: "out_of_scope",
        **lastmod_attributes(entry.lastmod),
        created_at: @clock.call
      }
    end

    def frontier_entry(scan, url)
      configuration = scan.settings_snapshot.to_h.stringify_keys
      FrontierEntry.new(
        url: url,
        depth: 0,
        priority: 50,
        discovery_source: "sitemap",
        query_handling: configuration.fetch("query_handling", "all"),
        query_parameter_allowlist: configuration.fetch("query_parameter_allowlist", []),
        query_parameter_denylist: configuration.fetch("query_parameter_denylist", [])
      )
    end

    def admit_page_candidates!(scan, state)
      candidates = state.fetch(:page_candidates)
      return if candidates.empty?

      digests = candidates.map { |_row, entry| entry.normalized_url_digest }
      existing = CrawlUrl.where(scan_id: scan.id, normalized_url_digest: digests)
        .index_by(&:normalized_url_digest)
      capacity = [ scan.settings_snapshot.to_h.fetch("max_urls", 0).to_i - scan.reload.urls_discovered_count, 0 ].max
      selected_new = candidates.reject { |_row, entry| existing.key?(entry.normalized_url_digest) }
        .first(capacity).to_h { |_row, entry| [ entry.normalized_url_digest, true ] }
      admitted = candidates.select do |_row, entry|
        existing.key?(entry.normalized_url_digest) || selected_new.key?(entry.normalized_url_digest)
      end

      admitted.each_slice(FRONTIER_BATCH_SIZE) do |batch|
        result = DiscoverFrontier.new(clock: @clock).call(
          organization_id: scan.organization_id,
          scan_id: scan.id,
          entries: batch.map(&:last)
        )
        result.items.each { |item| existing[item.normalized_url_digest] = item }
      end

      candidates.each do |row, entry|
        item = existing[entry.normalized_url_digest]
        if item.nil?
          row[:relationship_status] = "frontier_limit"
          warn_entry!(state, "frontier_limit", row.fetch(:entry_index))
        elsif selected_new.key?(entry.normalized_url_digest)
          row[:relationship_status] = "frontier_inserted"
          row[:crawl_url_id] = item.id
        else
          row[:relationship_status] = "frontier_duplicate"
          row[:crawl_url_id] = item.id
        end
        state[:rows] << row
      end
    end

    def sitemap_relationship(scan:, discovery:, file_scope:, parent:, entry:, normalized:)
      depth = parent.index_depth + 1
      if depth > setting(:crawler_sitemap_max_index_depth)
        add_discovery_warning!(discovery, "index_depth_limit")
        return [ "depth_rejected", nil ]
      end

      existing = SitemapFile.find_by(scan_id: scan.id, url_digest: normalized.identity_digest)
      if existing
        verify_file_identity!(existing, normalized.fetch_url)
        return [ ancestor_ids(parent).include?(existing.id) ? "circular" : "duplicate", existing ]
      end
      if discovery.sitemap_files.count >= setting(:crawler_sitemap_max_documents)
        add_discovery_warning!(discovery, "document_limit")
        return [ "document_limit", nil ]
      end

      child = add_file_candidate(
        scan: scan,
        discovery: discovery,
        file_scope: file_scope,
        url: entry.location,
        source: "sitemap_index",
        parent: parent,
        index_depth: depth
      )
      [ child&.status == "pending" ? "queued" : "out_of_scope", child ]
    end

    def ancestor_ids(file)
      ids = [ file.id ]
      current = file
      while current.parent_sitemap_file_id
        ids << current.parent_sitemap_file_id
        current = SitemapFile.find(current.parent_sitemap_file_id)
      end
      ids
    end

    def relationship_warning(status)
      {
        "circular" => "circular_index",
        "depth_rejected" => "index_depth_limit",
        "document_limit" => "document_limit",
        "out_of_scope" => "url_out_of_scope"
      }[status]
    end

    def persist_entry_rows!(rows)
      optional = {
        lastmod_text: nil,
        lastmod_at: nil,
        lastmod_precision: nil,
        crawl_url_id: nil,
        child_sitemap_file_id: nil
      }
      rows.each_slice(500) do |batch|
        normalized = batch.map { |row| optional.merge(row) }
        SitemapEntry.insert_all(
          normalized,
          unique_by: :index_crawl_sitemap_entries_on_file_location
        )
        verify_entry_rows!(normalized)
      end
    end

    def verify_entry_rows!(expected_rows)
      expected = expected_rows.index_by do |row|
        [ row.fetch(:sitemap_file_id), row.fetch(:entry_kind), row.fetch(:location_digest) ]
      end
      files = expected_rows.map { |row| row.fetch(:sitemap_file_id) }.uniq
      digests = expected_rows.map { |row| row.fetch(:location_digest) }.uniq
      actual = SitemapEntry.where(sitemap_file_id: files, location_digest: digests).to_a.index_by do |row|
        [ row.sitemap_file_id, row.entry_kind, row.location_digest ]
      end
      collision = expected.any? do |key, row|
        stored = actual[key]
        stored.nil? || stored.location_url != row.fetch(:location_url) ||
          stored.normalization_version != row.fetch(:normalization_version)
      end
      raise Conflict.new(reason_code: "sitemap_entry_digest_collision") if collision
    end

    def lastmod_attributes(value)
      return {} if value.blank?

      text = value.to_s
      if text.match?(/\A\d{4}-\d{2}-\d{2}\z/)
        date = Date.iso8601(text)
        { lastmod_text: text, lastmod_at: Time.utc(date.year, date.month, date.day), lastmod_precision: "date" }
      elsif text.match?(/\A\d{4}-\d{2}-\d{2}T.+(?:Z|[+-]\d{2}:\d{2})\z/)
        { lastmod_text: text, lastmod_at: Time.iso8601(text), lastmod_precision: "datetime" }
      else
        { lastmod_text: text, lastmod_precision: "invalid" }
      end
    rescue ArgumentError
      { lastmod_text: text, lastmod_precision: "invalid" }
    end

    def warn_entry!(state, code, entry_index)
      return if state[:warnings].length >= SitemapParser::MAXIMUM_WARNINGS

      state[:warnings] << SitemapWarning.new(code: code, entry_index: entry_index)
    end

    def bounded_warnings(values)
      values.first(SitemapParser::MAXIMUM_WARNINGS)
    end

    def parser_for(discovery)
      return @parser if @parser

      remaining = remaining_entry_budget(discovery)
      SitemapParser.new(
        max_entries: [ setting(:crawler_sitemap_max_entries_per_document), remaining ].min,
        max_depth: setting(:crawler_sitemap_max_xml_depth)
      )
    end

    def decoder
      @decoder ||= DecodeSitemapPayload.new(
        max_compressed_bytes: setting(:crawler_sitemap_max_response_bytes),
        max_decompressed_bytes: setting(:crawler_sitemap_max_decompressed_bytes)
      )
    end

    def remaining_entry_budget(discovery)
      consumed = discovery.sitemap_files.where.not(status: "pending").sum(:entry_count)
      [ setting(:crawler_sitemap_max_entries_per_scan) - consumed, 0 ].max
    end

    def add_discovery_warning!(discovery, code)
      values = Array(discovery.warning_codes)
      return if values.include?(code) || values.length >= SitemapParser::MAXIMUM_WARNINGS

      discovery.update!(warning_codes: values + [ code ])
    end

    def finalize_discovery!(discovery)
      files = discovery.sitemap_files
      processed = files.where.not(status: "pending")
      succeeded = processed.where(status: "fetched").count
      failed = processed.where.not(status: "fetched").count
      status = if processed.none?
        "completed"
      elsif succeeded.zero?
        "failed"
      elsif failed.positive? || discovery.warning_codes.any?
        "partially_completed"
      else
        "completed"
      end
      attempts, metered = fetch_meter_counts(processed)
      discovery.update!(
        status: status,
        documents_discovered_count: files.count,
        documents_processed_count: processed.count,
        documents_succeeded_count: succeeded,
        documents_failed_count: failed,
        entries_observed_count: processed.sum(:entry_count),
        entries_in_scope_count: processed.sum(:entries_in_scope_count),
        entries_out_of_scope_count: processed.sum(:entries_out_of_scope_count),
        entries_invalid_count: processed.sum(:entries_invalid_count),
        frontier_inserted_count: CrawlUrl.where(
          scan_id: discovery.scan_id, discovery_source: "sitemap"
        ).count,
        fetch_attempt_count: attempts,
        metered_fetch_count: metered,
        compressed_bytes_count: processed.sum(:compressed_bytes),
        decompressed_bytes_count: processed.sum(:decompressed_bytes),
        warning_count: processed.sum(:warning_count) + discovery.warning_codes.length,
        finished_at: @clock.call
      )
      discovery
    end

    def fetch_meter_counts(processed)
      attempts = 0
      metered = 0
      processed.where.not(status: "rejected").pluck(:http_status, :redirect_count).each do |status, redirects|
        redirect_responses = redirects.to_i
        attempts += redirect_responses + 1
        metered += redirect_responses + (status.nil? ? 0 : 1)
      end
      [ attempts, metered ]
    end

    def setting(key)
      (@settings || Rails.application.config.x.searchops).fetch(key)
    end
  end
end
