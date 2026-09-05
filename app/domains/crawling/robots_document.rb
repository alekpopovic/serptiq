# frozen_string_literal: true

module Crawling
  RobotsDocument = Data.define(:groups, :sitemap_urls, :warnings, :parser_version, :malformed) do
    def initialize(groups:, sitemap_urls:, warnings:, parser_version:, malformed: false)
      normalized_groups = Array(groups).map do |value|
        value.is_a?(RobotsGroup) ? value : RobotsGroup.new(**value.to_h.symbolize_keys)
      end.freeze
      normalized_warnings = Array(warnings).map do |value|
        value.is_a?(RobotsWarning) ? value : RobotsWarning.new(**value.to_h.symbolize_keys)
      end.freeze
      super(
        groups: normalized_groups,
        sitemap_urls: Array(sitemap_urls).map { |value| value.to_s.freeze }.freeze,
        warnings: normalized_warnings,
        parser_version: Integer(parser_version),
        malformed: malformed == true
      )
      freeze
    end

    def rules_for(product_token)
      token = product_token.to_s.downcase
      exact = groups.select { |group| group.agents.any? { |agent| agent.casecmp?(token) } }
      selected = exact.presence || groups.select { |group| group.agents.include?("*") }
      selected.flat_map(&:rules).uniq { |rule| [ rule.directive, rule.normalized_pattern ] }.freeze
    end

    def as_json(*)
      {
        "groups" => groups.map(&:as_json),
        "sitemap_urls" => sitemap_urls,
        "warnings" => warnings.map(&:as_json),
        "parser_version" => parser_version,
        "malformed" => malformed
      }
    end
  end
end
