# frozen_string_literal: true

require "digest"

module Crawling
  class CacheRobotsPolicy
    ACTIVE_SCAN_STATUSES = %w[admitted queued running cancel_requested].freeze

    def initialize(retriever: RetrieveRobots.new, parser: RobotsParser.new)
      @retriever = retriever
      @parser = parser
    end

    def call(organization_id:, scan_id:)
      scan = exact_scan!(organization_id, scan_id)
      environment = exact_environment!(scan)
      origin_digest = Digest::SHA256.hexdigest(environment.origin.origin)
      existing = RobotsSnapshot.find_by(scan_id: scan.id, origin_digest: origin_digest)
      verify_origin!(existing, environment.origin.origin) if existing
      return existing if existing

      retrieval = @retriever.call(origin: environment.origin)
      document, status = document_for(retrieval)
      create_snapshot(scan, environment, origin_digest, retrieval, document, status)
    rescue ActiveRecord::RecordNotUnique
      snapshot = RobotsSnapshot.find_by!(
        scan_id: scan_id,
        organization_id: organization_id,
        origin_digest: origin_digest
      )
      verify_origin!(snapshot, environment.origin.origin)
      snapshot
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "robots_scope_unavailable"), cause: nil
    end

    private

    def exact_scan!(organization_id, scan_id)
      scan = Scan.find_by!(organization_id: organization_id, id: scan_id)
      raise Conflict.new(reason_code: "robots_scan_state_invalid") unless scan.status.in?(ACTIVE_SCAN_STATUSES)

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

    def verify_origin!(snapshot, origin)
      raise Conflict.new(reason_code: "robots_origin_digest_collision") unless snapshot.origin == origin
    end

    def document_for(retrieval)
      return [ empty_document, retrieval.status ] unless retrieval.status == "fetched"

      document = @parser.call(body: retrieval.body)
      [ document, document.malformed ? "malformed" : "fetched" ]
    rescue ArgumentError
      warning = RobotsWarning.new(code: "parser_limit", line_number: 0)
      [ empty_document(warnings: [ warning ], malformed: true), "malformed" ]
    end

    def empty_document(warnings: [], malformed: false)
      RobotsDocument.new(
        groups: [], sitemap_urls: [], warnings: warnings,
        parser_version: RobotsParser::VERSION, malformed: malformed
      )
    end

    def create_snapshot(scan, environment, origin_digest, retrieval, document, status)
      error_code = retrieval.error_code
      error_code ||= "parser_malformed" if status == "malformed"
      RobotsSnapshot.create!(
        organization_id: scan.organization_id,
        project_id: scan.project_id,
        property_id: scan.property_id,
        environment_id: scan.environment_id,
        scan_id: scan.id,
        origin: environment.origin.origin,
        origin_digest: origin_digest,
        source_url: retrieval.source_url,
        final_url: retrieval.final_url,
        retrieval_status: status,
        http_status: retrieval.http_status,
        retrieved_at: retrieval.retrieved_at,
        artifact_sha256: retrieval.artifact_sha256,
        parser_version: document.parser_version,
        redirect_count: retrieval.redirect_count,
        error_code: error_code,
        groups: document.groups.map(&:as_json),
        sitemap_urls: document.sitemap_urls,
        warnings: document.warnings.map(&:as_json),
        malformed: document.malformed
      )
    end
  end
end
