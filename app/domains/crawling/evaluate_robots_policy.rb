# frozen_string_literal: true

require "addressable/uri"

module Crawling
  class EvaluateRobotsPolicy
    MAXIMUM_CACHE_AGE = 24.hours
    STATUS_REASONS = {
      "unavailable" => [ "allowed", "robots_unavailable" ],
      "unreachable" => [ "unknown", "robots_unreachable" ],
      "oversized" => [ "unknown", "robots_oversized" ],
      "malformed" => [ "unknown", "robots_malformed" ]
    }.freeze

    def initialize(normalizer: UrlNormalizer.new, clock: -> { Time.current })
      @normalizer = normalizer
      @clock = clock
    end

    def call(organization_id:, scan_id:, url:)
      scan = Scan.find_by!(organization_id: organization_id, id: scan_id)
      snapshot = RobotsSnapshot.find_by!(organization_id: organization_id, scan_id: scan_id)
      normalized = @normalizer.call(url: url, query_handling: "all")
      ensure_origin!(snapshot, normalized)

      return decision(snapshot, normalized.fetch_url, "allowed", "verified_owner_override") if
        scan.settings_snapshot.to_h.stringify_keys["robots_behavior"] == "verified_owner_override"
      return decision(snapshot, normalized.fetch_url, "unknown", "robots_snapshot_stale") if
        snapshot.retrieved_at < @clock.call - MAXIMUM_CACHE_AGE

      status = STATUS_REASONS[snapshot.retrieval_status]
      return decision(snapshot, normalized.fetch_url, *status) if status
      return decision(snapshot, normalized.fetch_url, "allowed", "robots_txt_implicit") if
        normalized.path == "/robots.txt"

      evaluate_rules(snapshot, normalized)
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "robots_scope_unavailable"), cause: nil
    rescue ArgumentError
      raise Invalid.new(
        field_errors: { url: "URL must be a canonical HTTP(S) target for this robots origin." },
        reason_code: "robots_url_invalid"
      ), cause: nil
    end

    private

    def ensure_origin!(snapshot, normalized)
      raise AccessDenied.new(reason_code: "robots_scope_unavailable") unless normalized.origin == snapshot.origin
    end

    def evaluate_rules(snapshot, normalized)
      uri = Addressable::URI.parse(normalized.fetch_url)
      request_target = RobotsOctets.normalize(
        uri.query.nil? ? uri.path : "#{uri.path}?#{uri.query}"
      )
      matches = snapshot.document.rules_for(CrawlerIdentity::PRODUCT_TOKEN).select do |rule|
        rule.match?(request_target)
      end
      winner = matches.max_by { |rule| [ rule.specificity, rule.allow? ? 1 : 0 ] }
      return decision(snapshot, normalized.fetch_url, "allowed", "no_matching_rule") unless winner

      outcome = winner.allow? ? "allowed" : "denied"
      reason = winner.allow? ? "explicit_allow" : "explicit_disallow"
      decision(snapshot, normalized.fetch_url, outcome, reason, winner)
    end

    def decision(snapshot, url, outcome, reason, rule = nil)
      RobotsDecision.new(
        outcome: outcome,
        reason_code: reason,
        snapshot_id: snapshot.id,
        parser_version: snapshot.parser_version,
        artifact_sha256: snapshot.artifact_sha256,
        retrieved_at: snapshot.retrieved_at,
        evaluated_url: url,
        matched_rule: rule&.as_json
      )
    end
  end
end
