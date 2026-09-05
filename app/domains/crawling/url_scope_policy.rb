# frozen_string_literal: true

module Crawling
  class UrlScopePolicy
    MAXIMUM_ALLOWED_HOSTS = 20
    ALLOWED_REASON_CODES = %w[same_origin allowed_host].freeze
    DENIED_REASON_CODES = %w[
      url_invalid depth_invalid depth_exceeded scheme_out_of_scope port_out_of_scope
      host_out_of_scope path_excluded path_not_included
    ].freeze

    attr_reader :origin, :allowed_hosts, :max_depth

    def initialize(origin:, allowed_hosts: [], include_patterns: [], exclude_patterns: [], max_depth:,
      query_handling: "all", query_parameter_allowlist: [], query_parameter_denylist: [],
      normalizer: UrlNormalizer.new)
      origin_value = origin.respond_to?(:origin) ? origin.origin : origin
      @origin = Properties::Public.canonical_origin(origin: origin_value)
      @allowed_hosts = normalize_allowed_hosts(allowed_hosts)
      @include_patterns = compile_patterns(include_patterns)
      @exclude_patterns = compile_patterns(exclude_patterns)
      @max_depth = Integer(max_depth)
      raise ArgumentError, "maximum crawl depth is invalid" unless @max_depth.between?(0, 100)

      @normalizer = normalizer
      @normalization_options = {
        query_handling: query_handling,
        query_parameter_allowlist: query_parameter_allowlist,
        query_parameter_denylist: query_parameter_denylist
      }.freeze
      freeze
    end

    def evaluate(url:, depth:)
      normalized_depth = normalize_depth(depth)
      return decision(false, "depth_invalid") if normalized_depth.nil? || normalized_depth.negative?
      return decision(false, "depth_exceeded") if normalized_depth > max_depth

      normalized = @normalizer.call(url: url, **@normalization_options)
      reason = scope_reason(normalized)
      decision(ALLOWED_REASON_CODES.include?(reason), reason, normalized)
    rescue ArgumentError, TypeError
      decision(false, "url_invalid")
    end

    private

    def normalize_depth(value)
      return value if value.is_a?(Integer)
      return unless value.is_a?(String) && value.match?(/\A-?[0-9]+\z/)

      Integer(value, 10)
    end

    def scope_reason(normalized)
      return "scheme_out_of_scope" unless normalized.scheme == origin.scheme
      return "port_out_of_scope" unless normalized.port == origin.port
      return "host_out_of_scope" unless normalized.host == origin.host || allowed_hosts.include?(normalized.host)
      return "path_excluded" if @exclude_patterns.any? { |pattern| pattern.match?(normalized.path) }
      return "path_not_included" if @include_patterns.any? &&
        @include_patterns.none? { |pattern| pattern.match?(normalized.path) }

      normalized.host == origin.host ? "same_origin" : "allowed_host"
    end

    def normalize_allowed_hosts(values)
      hosts = Array(values)
      raise ArgumentError, "too many allowed crawl hosts" if hosts.length > MAXIMUM_ALLOWED_HOSTS

      hosts.map do |host|
        candidate = Properties::Public.canonical_origin(
          origin: "#{origin.scheme}://#{host}:#{origin.port}"
        )
        candidate.host
      end.uniq.sort.freeze
    end

    def compile_patterns(values)
      Array(values).map { |value| value.is_a?(GlobPattern) ? value : GlobPattern.new(value: value) }.freeze
    end

    def decision(allowed, reason_code, normalized = nil)
      UrlScopeDecision.new(
        allowed: allowed,
        reason_code: reason_code,
        normalized_url: normalized
      )
    end
  end
end
