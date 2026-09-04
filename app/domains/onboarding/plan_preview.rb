# frozen_string_literal: true

module Onboarding
  PlanPreview = Data.define(
    :projects, :website_properties, :mobile_properties, :crawl_max_urls,
    :manual_crawl_enabled, :rendering_enabled
  ) do
    def initialize(**attributes)
      super(**attributes)
      freeze
    end
  end
end
