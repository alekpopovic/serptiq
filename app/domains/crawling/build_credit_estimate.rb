# frozen_string_literal: true

module Crawling
  class BuildCreditEstimate
    def call(configuration:, at: Time.current)
      catalog = Usage::Public.validate_catalog
      weights = catalog.meters.to_h do |meter|
        rate = meter.rates.select { |candidate| candidate.effective_at <= at }.max_by(&:effective_at)
        [ meter.key, rate&.weight ]
      end
      http_weight = weights.fetch("crawl.http_fetch")
      rendered_weight = weights.fetch("crawl.rendered_page")
      rendered_pages = configuration.max_rendered_pages
      maximum = configuration.max_urls * http_weight + rendered_pages * rendered_weight
      CreditEstimate.new(
        http_pages: configuration.max_urls,
        rendered_pages: rendered_pages,
        http_weight: http_weight,
        rendered_weight: rendered_weight,
        maximum_credits: maximum
      )
    end
  end
end
