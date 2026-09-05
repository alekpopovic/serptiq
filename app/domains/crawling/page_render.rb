# frozen_string_literal: true

require "digest"
require "json"

module Crawling
  class PageRender < ApplicationRecord
    self.table_name = "crawl_page_renders"

    STATES = %w[pending processing completed failed canceled skipped].freeze
    TERMINAL_STATES = %w[completed failed canceled skipped].freeze
    JSON_LIMITS = {
      console_messages: 32.kilobytes,
      page_errors: 32.kilobytes,
      network_summary: 64.kilobytes
    }.freeze

    belongs_to :scan, class_name: "Crawling::Scan"
    belongs_to :page_snapshot, class_name: "Crawling::PageSnapshot", inverse_of: :page_render
    belongs_to :page_fact, class_name: "Crawling::PageFact", inverse_of: :source_page_render
    belongs_to :rendered_dom_artifact, class_name: "Crawling::Artifact", optional: true
    belongs_to :screenshot_artifact, class_name: "Crawling::Artifact", optional: true
    has_one :rendered_page_fact, class_name: "Crawling::RenderedPageFact",
      inverse_of: :page_render, dependent: :restrict_with_exception
    has_many :rendered_links, class_name: "Crawling::RenderedLink",
      inverse_of: :page_render, dependent: :restrict_with_exception

    validates :organization_id, :project_id, :property_id, :environment_id, :scan_id,
      :page_snapshot_id, :page_fact_id, :state, :requested_url, :requested_url_digest,
      presence: true
    validates :state, inclusion: { in: STATES }
    validates :attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :maximum_attempts, numericality: { only_integer: true, in: 1..10 }
    validates :worker_id, format: { with: CrawlUrl::WORKER_PATTERN }, allow_nil: true
    validates :lease_token_digest, :requested_url_digest, :final_url_digest, :rendered_dom_sha256,
      format: { with: CrawlUrl::DIGEST_PATTERN }, allow_nil: true
    validates :failure_category, format: { with: CrawlUrl::FAILURE_PATTERN }, allow_nil: true
    validates :requested_url, :final_url, length: { in: 1..8192 }, allow_nil: true
    validates :renderer_version, :ferrum_version, :protocol_version,
      format: { with: Scan::VERSION_PATTERN }, allow_nil: true
    validates :browser_product, :browser_revision, length: { in: 1..128 }, allow_nil: true
    validates :duration_ms, numericality: { only_integer: true, in: 0..300_000 }, allow_nil: true
    validates :request_count, numericality: { only_integer: true, in: 1..5000 }, allow_nil: true
    validates :response_bytes, numericality: { only_integer: true, in: 0..500.megabytes }, allow_nil: true
    validate :identifier_shapes
    validate :source_shape
    validate :lifecycle_shape
    validate :result_shape
    validate :bounded_json

    STATES.each { |value| define_method("#{value}?") { state == value } }

    def terminal?
      state.in?(TERMINAL_STATES)
    end

    def lease_token_matches?(token)
      return false unless lease_token_digest&.match?(CrawlUrl::DIGEST_PATTERN)

      ActiveSupport::SecurityUtils.secure_compare(
        lease_token_digest,
        Digest::SHA256.hexdigest(token.to_s)
      )
    end

    private

    def identifier_shapes
      %i[organization_id project_id property_id environment_id scan_id].each do |name|
        errors.add(name, "is invalid") unless Shared::Public.application_uuid?(public_send(name))
      end
    end

    def source_shape
      return if requested_url.blank? || requested_url_digest.blank?

      expected = Digest::SHA256.hexdigest(requested_url)
      errors.add(:requested_url_digest, "does not match requested URL") unless
        ActiveSupport::SecurityUtils.secure_compare(expected, requested_url_digest)
    end

    def lifecycle_shape
      lease = [ worker_id, lease_token_digest, started_at, lease_expires_at ]
      valid = if pending?
        lease.all?(&:nil?) && next_attempt_at.present? && finished_at.nil?
      elsif processing?
        lease.none?(&:nil?) && next_attempt_at.nil? && finished_at.nil? && lease_expires_at > started_at
      else
        terminal? && lease.all?(&:nil?) && next_attempt_at.nil? && finished_at.present?
      end
      errors.add(:state, "does not match render lifecycle") unless valid
    end

    def result_shape
      result = [
        final_url, final_url_digest, rendered_dom_artifact_id, rendered_dom_sha256,
        renderer_version, ferrum_version, browser_product, browser_revision,
        protocol_version, duration_ms, request_count, response_bytes
      ]
      valid = completed? ? result.none?(&:nil?) : result.all?(&:nil?)
      valid &&= completed? ? (screenshot_enabled == screenshot_artifact_id.present?) : screenshot_artifact_id.nil?
      errors.add(:state, "does not match render result") unless valid
    end

    def bounded_json
      JSON_LIMITS.each do |name, limit|
        value = public_send(name)
        expected = name == :network_summary ? Hash : Array
        valid = value.is_a?(expected) && JSON.generate(value).bytesize <= limit
        valid &&= value.length <= 100 unless name == :network_summary
        errors.add(name, "must be bounded #{expected.name.downcase}") unless valid
      rescue JSON::GeneratorError
        errors.add(name, "must be bounded #{expected.name.downcase}")
      end
    end
  end
end
