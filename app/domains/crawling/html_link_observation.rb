# frozen_string_literal: true

module Crawling
  HtmlLinkObservation = Data.define(
    :destination_url, :destination_url_digest, :destination_host_digest,
    :normalization_version, :classification, :scope_status, :scope_reason,
    :source_locator, :rel_tokens, :anchor_summary, :anchor_digest,
    :occurrence_count, :nofollow_count
  ) do
    def initialize(**attributes)
      attributes[:rel_tokens] = Array(attributes.fetch(:rel_tokens)).map(&:to_s).uniq.sort.freeze
      %i[
        destination_url destination_url_digest destination_host_digest classification
        scope_status scope_reason source_locator anchor_digest
      ].each { |name| attributes[name] = attributes.fetch(name).to_s.freeze }
      attributes[:anchor_summary] = attributes[:anchor_summary]&.to_s&.freeze
      attributes[:normalization_version] = Integer(attributes.fetch(:normalization_version))
      attributes[:occurrence_count] = Integer(attributes.fetch(:occurrence_count))
      attributes[:nofollow_count] = Integer(attributes.fetch(:nofollow_count))
      super(**attributes)
      freeze
    end

    def internal?
      classification == "internal"
    end

    def discoverable?
      internal? && scope_status == "allowed"
    end
  end
end
