# frozen_string_literal: true

require "json"

module Crawling
  class RenderedPageFact < ApplicationRecord
    self.table_name = "crawl_rendered_page_facts"

    belongs_to :scan, class_name: "Crawling::Scan"
    belongs_to :page_render, class_name: "Crawling::PageRender", inverse_of: :rendered_page_fact

    validates :organization_id, :project_id, :property_id, :environment_id, :scan_id,
      :page_render_id, :parser_version, :content_sha256, :fact_digest, :parse_status,
      presence: true
    validates :parser_version, format: { with: Scan::VERSION_PATTERN }
    validates :content_sha256, :fact_digest, format: { with: CrawlUrl::DIGEST_PATTERN }
    validates :parse_status, inclusion: { in: %w[parsed malformed] }
    validate :identifier_shapes
    validate :bounded_facts

    private

    def identifier_shapes
      %i[organization_id project_id property_id environment_id scan_id].each do |name|
        errors.add(name, "is invalid") unless Shared::Public.application_uuid?(public_send(name))
      end
    end

    def bounded_facts
      valid = facts.is_a?(Hash) && JSON.generate(facts).bytesize <= 768.kilobytes
      errors.add(:facts, "must be a bounded object") unless valid
    rescue JSON::GeneratorError
      errors.add(:facts, "must be a bounded object")
    end
  end
end
