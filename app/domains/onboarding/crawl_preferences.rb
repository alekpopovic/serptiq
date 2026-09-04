# frozen_string_literal: true

module Onboarding
  CrawlPreferences = Data.define(:max_urls, :max_depth, :query_handling, :obey_robots, :rendering) do
    def initialize(max_urls:, max_depth:, query_handling:, obey_robots:, rendering:, plan_preview:)
      urls = integer(max_urls)
      depth = integer(max_depth)
      query = query_handling.to_s
      errors = {}
      robots = boolean(obey_robots, :crawl_obey_robots, errors)
      render_pages = boolean(rendering, :crawl_rendering, errors)
      errors[:max_urls] = "Enter a maximum between 1 and 200000." unless
        urls&.between?(1, 200_000)
      errors[:max_depth] = "Enter a crawl depth between 0 and 20." unless
        depth&.between?(0, 20)
      errors[:query_handling] = "Choose how query parameters are handled." unless
        Draft::QUERY_HANDLING.include?(query)
      entitlement = plan_preview.crawl_max_urls
      unless entitlement.enabled? && entitlement.value.is_a?(Integer) && entitlement.value.positive?
        errors[:max_urls] = "Your effective plan does not currently allow crawl URLs."
      end
      if urls && entitlement.enabled? && entitlement.value.is_a?(Integer) && urls > entitlement.value
        errors[:max_urls] = "Use no more than your effective plan limit of #{entitlement.value} URLs."
      end
      errors[:max_urls] = "Manual scans are unavailable for the effective plan." unless
        plan_preview.manual_crawl_enabled
      if render_pages && !plan_preview.rendering_enabled
        errors[:rendering] = "JavaScript rendering is unavailable for the effective plan."
      end
      raise Invalid.new(field_errors: errors) if errors.any?

      super(
        max_urls: urls,
        max_depth: depth,
        query_handling: query.freeze,
        obey_robots: robots,
        rendering: render_pages
      )
      freeze
    end

    private

    def integer(value)
      Integer(value, exception: false)
    end

    def boolean(value, field, errors)
      return true if value == true || value == 1 || value == "1"
      return false if value.nil? || value == false || value == 0 || value == "0"

      errors[field] = "Choose a valid yes or no value."
      false
    end
  end
end
