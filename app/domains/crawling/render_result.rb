# frozen_string_literal: true

module Crawling
  RenderResult = Data.define(
    :final_url, :dom, :screenshot, :duration_ms, :request_count, :response_bytes,
    :console_messages, :page_errors, :network_summary, :renderer_version,
    :ferrum_version, :browser_product, :browser_revision, :protocol_version
  ) do
    def initialize(**attributes)
      %i[dom screenshot].each do |name|
        value = attributes[name]
        attributes[name] = value&.dup&.freeze
      end
      %i[console_messages page_errors].each do |name|
        attributes[name] = Array(attributes.fetch(name)).map { |value| value.to_s.dup.freeze }.freeze
      end
      attributes[:network_summary] = attributes.fetch(:network_summary).deep_dup.freeze
      super(**attributes)
      freeze
    end
  end
end
