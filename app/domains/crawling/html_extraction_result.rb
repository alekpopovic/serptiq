# frozen_string_literal: true

module Crawling
  HtmlExtractionResult = Data.define(
    :parser_version, :content_sha256, :parse_status, :parse_error_count,
    :element_count, :effective_base_url, :title_status, :title_summary,
    :title_digest, :description_status, :description_summary, :description_digest,
    :language_status, :document_language, :fact_statuses, :meta_directives,
    :headings, :canonicals, :hreflangs, :images, :structured_data_blocks,
    :counts, :links
  ) do
    def initialize(**attributes)
      attributes[:links] = Array(attributes.fetch(:links)).freeze
      super(**attributes)
      freeze
    end

    def fact_attributes
      to_h.except(:links)
    end
  end
end
