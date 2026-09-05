# frozen_string_literal: true

require "digest"
require "json"

module Crawling
  class PersistHtmlExtraction
    Persisted = Data.define(:page_fact, :frontier_linked_count)

    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(snapshot:, extraction:, destinations:, frontier_linked_count:)
      verify_content!(snapshot, extraction)
      fact_attributes = extraction.fact_attributes.merge(
        counts: extraction.counts.merge("frontier_linked" => frontier_linked_count)
      )
      fact_digest = digest(fact_attributes)
      fact = nil
      PageFact.transaction do
        fact = PageFact.find_or_initialize_by(page_snapshot_id: snapshot.id)
        if fact.new_record?
          fact.assign_attributes(
            tenant_attributes(snapshot).merge(
              fact_attributes,
              fact_digest: fact_digest
            )
          )
          fact.save!
        elsif fact.fact_digest != fact_digest
          raise Conflict.new(reason_code: "page_fact_replay_conflict")
        end

        persist_links(snapshot, extraction.links, destinations)
      end
      Persisted.new(fact, frontier_linked_count)
    rescue ActiveRecord::RecordNotUnique
      retry
    end

    def unavailable(snapshot:, failure_category:)
      statuses = PageFact::FACT_KEYS.index_with { "unavailable" }
      attributes = {
        parser_version: HtmlPageExtractor::PARSER_VERSION,
        content_sha256: snapshot.fetch_result.body_sha256,
        parse_status: "unavailable",
        parse_error_count: 0,
        element_count: 0,
        effective_base_url: snapshot.fetch_result.final_url,
        title_status: "unavailable",
        title_summary: nil,
        title_digest: nil,
        description_status: "unavailable",
        description_summary: nil,
        description_digest: nil,
        language_status: "unavailable",
        document_language: nil,
        fact_statuses: statuses,
        meta_directives: [],
        headings: [],
        canonicals: [],
        hreflangs: [],
        images: [],
        structured_data_blocks: [],
        counts: { "failure_category" => failure_category, "frontier_linked" => 0 }
      }
      fact_digest = digest(attributes)
      fact = PageFact.find_or_initialize_by(page_snapshot_id: snapshot.id)
      if fact.new_record?
        fact.assign_attributes(tenant_attributes(snapshot).merge(attributes, fact_digest: fact_digest))
        fact.save!
      elsif fact.fact_digest != fact_digest
        raise Conflict.new(reason_code: "page_fact_replay_conflict")
      end
      fact
    rescue ActiveRecord::RecordNotUnique
      retry
    end

    private

    def verify_content!(snapshot, extraction)
      expected = snapshot.fetch_result.body_sha256
      actual = extraction.content_sha256
      valid = expected&.match?(CrawlUrl::DIGEST_PATTERN) &&
        ActiveSupport::SecurityUtils.secure_compare(expected, actual)
      raise Conflict.new(reason_code: "page_content_hash_mismatch") unless valid
    end

    def persist_links(snapshot, links, destinations)
      now = @clock.call
      rows = links.map do |link|
        destination_id = destinations[link.destination_url_digest]
        attributes = {
          **tenant_attributes(snapshot),
          page_snapshot_id: snapshot.id,
          source_crawl_url_id: snapshot.crawl_url_id,
          destination_crawl_url_id: destination_id,
          destination_url: link.destination_url,
          destination_url_digest: link.destination_url_digest,
          normalization_version: link.normalization_version,
          destination_host_digest: link.destination_host_digest,
          classification: link.classification,
          scope_status: link.scope_status,
          scope_reason: link.scope_reason,
          discovery_status: discovery_status(link, destination_id),
          source_locator: link.source_locator,
          rel_tokens: link.rel_tokens,
          anchor_summary: link.anchor_summary,
          anchor_digest: link.anchor_digest,
          nofollow: link.nofollow_count.positive?,
          occurrence_count: link.occurrence_count,
          nofollow_count: link.nofollow_count,
          discovered_at: now
        }
        attributes.merge(
          edge_digest: digest(attributes.except(:discovered_at)),
          created_at: now,
          updated_at: now
        )
      end
      CrawlLink.insert_all(rows, unique_by: :index_crawl_links_on_snapshot_destination) if rows.any?
      existing = CrawlLink.where(page_snapshot_id: snapshot.id).index_by(&:destination_url_digest)
      unless existing.length == rows.length && rows.all? do |row|
        existing[row.fetch(:destination_url_digest)]&.edge_digest == row.fetch(:edge_digest)
      end
        raise Conflict.new(reason_code: "crawl_link_replay_conflict")
      end
    end

    def discovery_status(link, destination_id)
      return "not_applicable" unless link.discoverable?

      destination_id ? "linked" : "not_admitted"
    end

    def tenant_attributes(snapshot)
      {
        organization_id: snapshot.organization_id,
        project_id: snapshot.project_id,
        property_id: snapshot.property_id,
        environment_id: snapshot.environment_id,
        scan_id: snapshot.scan_id,
        page_snapshot_id: snapshot.id
      }
    end

    def digest(value)
      Digest::SHA256.hexdigest(JSON.generate(canonical(value)))
    end

    def canonical(value)
      case value
      when Hash
        value.to_h.stringify_keys.sort.to_h { |key, item| [ key, canonical(item) ] }
      when Array
        value.map { |item| canonical(item) }
      else
        value
      end
    end
  end
end
