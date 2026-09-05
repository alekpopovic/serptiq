# frozen_string_literal: true

module Crawling
  class NormalizePolicy
    URL_LIST_LIMIT = 20
    PATTERN_LIST_LIMIT = 50
    URL_MAX_BYTES = 2048
    USER_AGENT_PATTERN = /\A[A-Za-z0-9][A-Za-z0-9._-]{0,31}\z/
    RESERVED_USER_AGENTS = %w[
      googlebot bingbot slurp duckduckbot baiduspider yandexbot facebookexternalhit
    ].freeze
    QUERY_HANDLING = %w[ignore tracking_only all].freeze

    def call(attributes:, origin:, limits:, verified_owner: false)
      values = attributes.to_h.symbolize_keys
      errors = {}
      start_urls = normalize_urls(values[:start_urls], :start_urls, origin, errors)
      sitemap_urls = normalize_urls(values[:sitemap_urls], :sitemap_urls, origin, errors, required: false)
      includes = normalize_patterns(values[:include_patterns], :include_patterns, limits, errors)
      excludes = normalize_patterns(values[:exclude_patterns], :exclude_patterns, limits, errors)
      max_urls = bounded_integer(values[:max_urls], :max_urls, 1, limits.max_urls, errors)
      max_depth = bounded_integer(values[:max_depth], :max_depth, 0, limits.max_depth, errors)
      query = values[:query_handling].to_s
      errors[:query_handling] = "Choose a supported query handling policy." unless QUERY_HANDLING.include?(query)
      query_allowlist = normalize_query_parameters(
        values[:query_parameter_allowlist], :query_parameter_allowlist, errors
      )
      query_denylist = normalize_query_parameters(
        values[:query_parameter_denylist], :query_parameter_denylist, errors
      )
      validate_query_parameter_policy(query, query_allowlist, query_denylist, errors)
      suffix = normalize_user_agent(values[:user_agent_suffix], limits, errors)
      rate = bounded_decimal(
        values[:request_rate_per_second], :request_rate_per_second,
        BigDecimal("0.1"), limits.max_request_rate, errors
      )
      concurrency = bounded_integer(
        values[:max_concurrency], :max_concurrency, 1, limits.max_concurrency, errors
      )
      robots = values[:robots_behavior].to_s
      validate_robots_behavior(robots, limits, verified_owner, errors)
      sample = bounded_integer(values[:rendering_sample_percent], :rendering_sample_percent, 0, 100, errors)
      rendered = bounded_integer(
        values[:max_rendered_pages], :max_rendered_pages, 0, limits.max_rendered_pages, errors
      )
      retention = bounded_integer(
        values[:artifact_retention_days], :artifact_retention_days,
        0, limits.artifact_retention_days, errors
      )
      validate_rendering(sample, rendered, max_urls, limits, errors)
      raise Invalid.new(field_errors: errors) if errors.any?

      PolicyConfiguration.new(
        start_urls: start_urls,
        sitemap_urls: sitemap_urls,
        include_patterns: includes,
        exclude_patterns: excludes,
        max_urls: max_urls,
        max_depth: max_depth,
        query_handling: query,
        query_parameter_allowlist: query_allowlist,
        query_parameter_denylist: query_denylist,
        user_agent_suffix: suffix,
        request_rate_per_second: rate,
        max_concurrency: concurrency,
        robots_behavior: robots,
        rendering_sample_percent: sample,
        max_rendered_pages: rendered,
        artifact_retention_days: retention
      )
    end

    private

    def normalize_urls(value, field, origin, errors, required: true)
      rows = list(value).uniq
      if (required && rows.empty?) || rows.length > URL_LIST_LIMIT
        errors[field] = required ? "Provide between 1 and #{URL_LIST_LIMIT} URLs." :
          "Provide no more than #{URL_LIST_LIMIT} URLs."
        return rows
      end

      rows.map do |raw|
        raise ArgumentError, "URL is too long" if raw.bytesize > URL_MAX_BYTES

        target = Shared::Public.http_target(url: raw)
        raise ArgumentError, "URL must use the environment origin" unless target.origin == origin.origin

        target.url
      rescue ArgumentError
        errors[field] = "Every URL must be an HTTP(S) URL on #{origin.display_origin}, without credentials or fragments."
        raw
      end
    end

    def normalize_patterns(value, field, limits, errors)
      rows = list(value).uniq
      if rows.length > PATTERN_LIST_LIMIT
        errors[field] = "Provide no more than #{PATTERN_LIST_LIMIT} patterns."
        return rows
      end
      if rows.any? && !limits.custom_patterns
        errors[field] = "Custom path patterns are unavailable for the effective plan."
        return rows
      end

      rows.map { |pattern| GlobPattern.new(value: pattern).value }
    rescue ArgumentError => error
      errors[field] = error.message
      rows
    end

    def normalize_user_agent(value, limits, errors)
      suffix = value.to_s.strip.presence
      return unless suffix
      unless limits.custom_user_agent
        errors[:user_agent_suffix] = "A custom crawler suffix is unavailable for the effective plan."
      end
      unless USER_AGENT_PATTERN.match?(suffix) && !RESERVED_USER_AGENTS.include?(suffix.downcase)
        errors[:user_agent_suffix] = "Use a short product token that does not impersonate another crawler."
      end
      suffix
    end

    def normalize_query_parameters(value, field, errors)
      rows = list(value).uniq
      if rows.length > PATTERN_LIST_LIMIT
        errors[field] = "Provide no more than #{PATTERN_LIST_LIMIT} parameter names."
        return rows
      end

      rows.map { |name| UrlQueryPolicy.normalize_parameter_name(name) }.uniq.sort
    rescue ArgumentError => error
      errors[field] = error.message
      rows
    end

    def validate_query_parameter_policy(query, allowlist, denylist, errors)
      if (allowlist & denylist).any?
        errors[:query_parameter_denylist] = "A parameter cannot appear in both query lists."
      end
      if query == "ignore" && (allowlist.any? || denylist.any?)
        errors[:query_handling] = "Query parameter lists cannot be used when all query parameters are ignored."
      end
    end

    def validate_robots_behavior(value, limits, verified_owner, errors)
      return if value == "respect"
      unless value == "verified_owner_override"
        errors[:robots_behavior] = "Choose a supported robots policy."
        return
      end
      unless limits.robots_override
        errors[:robots_behavior] = "A robots override is unavailable for the effective plan."
      end
      unless verified_owner
        errors[:robots_behavior] = "Verify current ownership before explicitly overriding robots rules."
      end
    end

    def bounded_integer(value, field, minimum, maximum, errors)
      parsed = Integer(value, exception: false)
      unless parsed&.between?(minimum, maximum)
        errors[field] = "Enter a value between #{minimum} and #{maximum}."
      end
      parsed
    end

    def bounded_decimal(value, field, minimum, maximum, errors)
      parsed = BigDecimal(value.to_s, exception: false)
      unless parsed&.between?(minimum, maximum) && parsed.scale <= 2
        errors[field] = "Enter a value between #{minimum.to_s('F')} and #{maximum.to_s('F')} with at most two decimals."
      end
      parsed
    end

    def validate_rendering(sample, rendered, max_urls, limits, errors)
      return unless sample && rendered && max_urls

      if sample.zero? != rendered.zero?
        errors[:rendering_sample_percent] = "Rendering percentage and page cap must both be zero or both be positive."
      elsif sample.positive?
        errors[:rendering_sample_percent] = "JavaScript rendering is unavailable for the effective plan." unless
          limits.rendering_enabled
        estimated = (max_urls * sample / 100.0).ceil
        if rendered > estimated
          errors[:max_rendered_pages] = "Use no more than the #{estimated}-page sample implied by this percentage."
        end
      end
    end

    def list(value)
      rows = value.is_a?(String) ? value.lines : Array(value)
      rows.map { |item| item.to_s.strip }.reject(&:blank?)
    end
  end
end
