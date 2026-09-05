# frozen_string_literal: true

module Crawling
  class RobotsParser
    VERSION = 1
    MAXIMUM_BYTES = 500.kilobytes
    MAXIMUM_LINES = 20_000
    MAXIMUM_GROUPS = 2_000
    MAXIMUM_RULES = 20_000
    MAXIMUM_RULE_BYTES = 2_048
    MAXIMUM_SITEMAPS = 100
    MAXIMUM_WARNINGS = 2_000
    PRODUCT_TOKEN_PATTERN = /\A(?:\*|[A-Za-z_-]+)\z/
    DIRECTIVE_LINE = /\A[ \t]*([A-Za-z-]+)[ \t]*:[ \t]*(.*?)[ \t]*\z/

    def initialize(url_normalizer: UrlNormalizer.new)
      @url_normalizer = url_normalizer
    end

    def call(body:)
      raw = body.to_s.b
      raise ArgumentError, "robots response is too large" if raw.bytesize > MAXIMUM_BYTES

      lines = raw.split(/\r\n|\n|\r/, -1)
      raise ArgumentError, "robots response has too many lines" if lines.length > MAXIMUM_LINES

      state = parse_lines(lines)
      RobotsDocument.new(
        groups: state.fetch(:groups),
        sitemap_urls: state.fetch(:sitemaps),
        warnings: state.fetch(:warnings),
        parser_version: VERSION,
        malformed: state.fetch(:malformed)
      )
    end

    private

    def parse_lines(lines)
      state = { groups: [], rule_count: 0, sitemaps: [], warnings: [], malformed: false }
      agents = []
      rules = []
      rules_started = false

      lines.each_with_index do |raw_line, index|
        line_number = index + 1
        line = utf8_line(raw_line, state, line_number)
        next unless line

        line = line.delete_prefix("\uFEFF") if line_number == 1
        content = line.split("#", 2).first.to_s.rstrip
        next if content.strip.empty?

        match = DIRECTIVE_LINE.match(content)
        unless match
          warn!(state, "malformed_line", line_number)
          next
        end

        directive = match[1].downcase
        value = match[2].to_s.strip
        if directive == "user-agent"
          if rules_started
            append_group!(state, agents, rules)
            agents = []
            rules = []
            rules_started = false
          end
          if PRODUCT_TOKEN_PATTERN.match?(value)
            agents << value.downcase
          else
            warn!(state, "invalid_user_agent", line_number)
          end
        elsif directive.in?(RobotsRule::DIRECTIVES)
          if agents.empty?
            warn!(state, "orphan_rule", line_number)
          else
            if value.present?
              rules_started = true
              rule = build_rule(directive, value, line_number, state)
              rules << rule if rule
            end
          end
        elsif directive == "sitemap"
          append_sitemap!(state, value, line_number)
        else
          warn!(state, "unsupported_directive", line_number)
        end
      end
      append_group!(state, agents, rules) if agents.any?
      state[:malformed] = state[:groups].empty? && state[:warnings].any? { |warning|
        warning.code.in?(%w[invalid_utf8 malformed_line invalid_user_agent])
      }
      state
    end

    def utf8_line(raw, state, line_number)
      line = raw.dup.force_encoding(Encoding::UTF_8)
      return line if line.valid_encoding?

      warn!(state, "invalid_utf8", line_number)
      nil
    end

    def build_rule(directive, value, line_number, state)
      unless value.start_with?("/", "*") && value.bytesize <= MAXIMUM_RULE_BYTES && !value.match?(/[ \t]/)
        warn!(state, "invalid_rule", line_number)
        return
      end
      normalized = RobotsOctets.normalize(value)
      specificity = normalized.delete("*").delete_suffix("$").bytesize
      RobotsRule.new(
        directive: directive,
        pattern: value,
        normalized_pattern: normalized,
        specificity: specificity,
        line_number: line_number
      )
    rescue ArgumentError
      warn!(state, "invalid_rule", line_number)
      nil
    end

    def append_group!(state, agents, rules)
      raise ArgumentError, "robots response has too many groups" if state[:groups].length >= MAXIMUM_GROUPS
      raise ArgumentError, "robots response has too many rules" if state[:rule_count] + rules.length > MAXIMUM_RULES

      state[:groups] << RobotsGroup.new(agents: agents, rules: rules)
      state[:rule_count] += rules.length
    end

    def append_sitemap!(state, value, line_number)
      if state[:sitemaps].length >= MAXIMUM_SITEMAPS
        warn!(state, "sitemap_limit", line_number)
        return
      end
      normalized = @url_normalizer.call(url: value, query_handling: "all").fetch_url
      state[:sitemaps] << normalized unless state[:sitemaps].include?(normalized)
    rescue ArgumentError
      warn!(state, "invalid_sitemap", line_number)
    end

    def warn!(state, code, line_number)
      return if state[:warnings].length >= MAXIMUM_WARNINGS

      state[:warnings] << RobotsWarning.new(code: code, line_number: line_number)
    end
  end
end
