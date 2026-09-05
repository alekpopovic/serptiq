# frozen_string_literal: true

module Crawling
  class Scan < ApplicationRecord
    self.table_name = "scans"

    STATUSES = %w[
      requested admitted queued running cancel_requested canceled completed
      partially_completed failed
    ].freeze
    TERMINAL_STATUSES = %w[canceled completed partially_completed failed].freeze
    SCAN_TYPES = %w[full targeted verification].freeze
    INITIATOR_TYPES = %w[membership schedule release system].freeze
    REQUEST_SOURCES = %w[manual schedule release].freeze
    FAILURE_CATEGORY_PATTERN = /\A[a-z][a-z0-9_]{0,63}\z/
    VERSION_PATTERN = /\A[A-Za-z0-9][A-Za-z0-9._+-]{0,63}\z/
    IMMUTABLE_INPUTS = %i[
      organization_id project_id property_id environment_id scan_type initiator_type
      initiated_by_membership_id settings_snapshot settings_digest entitlement_snapshot
      entitlement_digest engine_version rule_set_version configuration_version release_id
      baseline_scan_id requested_at
      request_source request_idempotency_digest request_checksum admission_version
      usage_quota_reservation_id domain_verification_id preflight_checked_at
      preflight_status_code preflight_destination_digest credit_estimate
    ].freeze

    has_many :events, class_name: "Crawling::ScanEvent", inverse_of: :scan,
      dependent: :restrict_with_exception
    has_many :crawl_urls, class_name: "Crawling::CrawlUrl", inverse_of: :scan,
      dependent: :restrict_with_exception
    has_many :robots_snapshots, class_name: "Crawling::RobotsSnapshot", inverse_of: :scan,
      dependent: :restrict_with_exception
    has_one :sitemap_discovery, class_name: "Crawling::SitemapDiscovery", inverse_of: :scan,
      dependent: :restrict_with_exception
    has_many :sitemap_files, class_name: "Crawling::SitemapFile", inverse_of: :scan,
      dependent: :restrict_with_exception
    has_many :sitemap_entries, class_name: "Crawling::SitemapEntry", inverse_of: :scan,
      dependent: :restrict_with_exception
    has_many :artifacts, class_name: "Crawling::Artifact", inverse_of: :scan,
      dependent: :restrict_with_exception
    has_many :fetch_permits, class_name: "Crawling::FetchPermit", inverse_of: :scan,
      dependent: :restrict_with_exception
    has_many :usage_operations, class_name: "Crawling::ScanUsageOperation", inverse_of: :scan,
      dependent: :restrict_with_exception
    has_one :static_crawl_execution, class_name: "Crawling::StaticCrawlExecution",
      inverse_of: :scan, dependent: :restrict_with_exception
    has_many :fetch_results, class_name: "Crawling::CrawlFetchResult", inverse_of: :scan,
      dependent: :restrict_with_exception
    has_many :page_snapshots, class_name: "Crawling::PageSnapshot", inverse_of: :scan,
      dependent: :restrict_with_exception
    has_one :policy_snapshot, class_name: "Crawling::PolicySnapshot", inverse_of: false,
      dependent: :restrict_with_exception
    belongs_to :baseline_scan, class_name: "Crawling::Scan", optional: true
    belongs_to :quota_reservation, class_name: "Usage::QuotaReservation",
      foreign_key: :usage_quota_reservation_id, optional: true
    belongs_to :verification_challenge, class_name: "Verification::Challenge",
      foreign_key: :domain_verification_id, optional: true

    validates :organization_id, :project_id, :property_id, :environment_id, :requested_at,
      presence: true
    validates :scan_type, inclusion: { in: SCAN_TYPES }
    validates :initiator_type, inclusion: { in: INITIATOR_TYPES }
    validates :status, inclusion: { in: STATUSES }
    validates :settings_digest, :entitlement_digest, format: { with: /\A[0-9a-f]{64}\z/ }
    validates :engine_version, :rule_set_version, format: { with: VERSION_PATTERN }
    validates :configuration_version, numericality: { only_integer: true, greater_than: 0 }
    validates :progress_sequence, numericality: { only_integer: true, greater_than: 0 }
    validates :failure_category, format: { with: FAILURE_CATEGORY_PATTERN }, allow_nil: true
    validates :request_source, inclusion: { in: REQUEST_SOURCES }, if: :admitted_by_request?
    validates :request_idempotency_digest, :request_checksum, :preflight_destination_digest,
      format: { with: /\A[0-9a-f]{64}\z/ }, if: :admitted_by_request?
    validates :admission_version, inclusion: { in: [ 1 ] }, allow_nil: true
    validates :preflight_status_code, numericality: {
      only_integer: true, greater_than_or_equal_to: 100, less_than: 500
    }, if: :admitted_by_request?
    validates :credit_estimate, numericality: { greater_than: 0 }, if: :admitted_by_request?
    validates :dispatch_attempt_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :dispatch_last_error_category, format: { with: FAILURE_CATEGORY_PATTERN }, allow_nil: true
    validates :throttle_reason, format: { with: FAILURE_CATEGORY_PATTERN }, allow_nil: true
    validate :identifier_shapes
    validate :initiator_shape
    validate :snapshots_are_bounded_objects
    validate :snapshot_digests_match
    validate :counter_consistency
    validate :lifecycle_consistency
    validate :inputs_are_immutable, on: :update
    validate :admission_provenance_consistency
    validate :dispatch_consistency
    validate :throttle_observation_consistency

    scope :terminal, -> { where(status: TERMINAL_STATUSES) }
    scope :active_work, -> { where.not(status: TERMINAL_STATUSES) }

    def terminal?
      status.in?(TERMINAL_STATUSES)
    end

    def cancellable?
      status.in?(%w[requested admitted queued running])
    end

    def successful_outcome?
      status.in?(%w[completed partially_completed])
    end

    def throttled?
      throttled_at.present?
    end

    def counters
      ScanCounters.new(**SCAN_COUNTER_ATTRIBUTES.to_h { |name| [ name, public_send(name) ] })
    end

    def finished_at
      completed_at || canceled_at || failed_at
    end

    private

    def admitted_by_request?
      admission_version.present?
    end

    def identifier_shapes
      %i[organization_id project_id property_id environment_id].each do |attribute|
        errors.add(attribute, "is invalid") unless Shared::Public.application_uuid?(public_send(attribute))
      end
      %i[initiated_by_membership_id release_id baseline_scan_id].each do |attribute|
        value = public_send(attribute)
        errors.add(attribute, "is invalid") if value.present? && !Shared::Public.application_uuid?(value)
      end
      errors.add(:baseline_scan_id, "cannot reference itself") if baseline_scan_id.present? && baseline_scan_id == id
    end

    def initiator_shape
      valid = if initiator_type == "membership"
        initiated_by_membership_id.present?
      else
        initiated_by_membership_id.nil?
      end
      errors.add(:initiator_type, "does not match the initiator reference") unless valid
    end

    def snapshots_are_bounded_objects
      { settings_snapshot: settings_snapshot, entitlement_snapshot: entitlement_snapshot }.each do |name, value|
        valid = value.is_a?(Hash) && JSON.generate(value).bytesize <= ScanSnapshot::MAX_BYTES
        errors.add(name, "must be a bounded object") unless valid
      end
    end

    def snapshot_digests_match
      {
        settings_snapshot: settings_digest,
        entitlement_snapshot: entitlement_digest
      }.each do |name, digest|
        snapshot = ScanSnapshot.new(value: public_send(name))
        errors.add("#{name.to_s.delete_suffix("_snapshot")}_digest", "does not match the snapshot") unless
          ActiveSupport::SecurityUtils.secure_compare(snapshot.digest, digest.to_s)
      rescue ArgumentError
        errors.add(name, "must be a valid scan snapshot")
      end
    end

    def counter_consistency
      counters
      if terminal? && (urls_queued_count.positive? || urls_running_count.positive?)
        errors.add(:status, "cannot be terminal while URL work remains active")
      end
    rescue ArgumentError => error
      errors.add(:base, error.message)
    end

    def lifecycle_consistency
      valid = case status
      when "requested"
        admitted_at.nil? && queued_at.nil? && started_at.nil? && cancel_requested_at.nil? && terminal_fields_empty?
      when "admitted"
        admitted_at.present? && queued_at.nil? && started_at.nil? && cancel_requested_at.nil? && terminal_fields_empty?
      when "queued"
        admitted_at.present? && queued_at.present? && started_at.nil? && cancel_requested_at.nil? &&
          terminal_fields_empty?
      when "running"
        admitted_at.present? && queued_at.present? && started_at.present? && cancel_requested_at.nil? &&
          terminal_fields_empty?
      when "cancel_requested"
        admitted_at.present? && queued_at.present? && cancel_requested_at.present? && terminal_fields_empty?
      when "canceled"
        cancel_requested_at.present? && canceled_at.present? && completed_at.nil? && failed_at.nil? &&
          failure_category.nil?
      when "completed", "partially_completed"
        started_at.present? && completed_at.present? && canceled_at.nil? && failed_at.nil? && failure_category.nil?
      when "failed"
        failed_at.present? && completed_at.nil? && canceled_at.nil? && failure_category.present?
      else
        false
      end
      valid &&= timestamps_are_ordered?
      errors.add(:status, "does not match lifecycle timestamps") unless valid
    end

    def terminal_fields_empty?
      canceled_at.nil? && completed_at.nil? && failed_at.nil? && failure_category.nil?
    end

    def timestamps_are_ordered?
      pairs = [
        [ admitted_at, requested_at ], [ queued_at, admitted_at ], [ started_at, queued_at ],
        [ cancel_requested_at, requested_at ], [ canceled_at, cancel_requested_at ],
        [ completed_at, started_at ], [ failed_at, requested_at ]
      ]
      pairs.all? { |later, earlier| later.nil? || (earlier.present? && later >= earlier) }
    end

    def inputs_are_immutable
      IMMUTABLE_INPUTS.each do |attribute|
        errors.add(attribute, "cannot be changed") if will_save_change_to_attribute?(attribute)
      end
    end

    def admission_provenance_consistency
      values = [
        request_source, request_idempotency_digest, request_checksum,
        usage_quota_reservation_id, domain_verification_id, preflight_checked_at,
        preflight_status_code, preflight_destination_digest, credit_estimate
      ]
      valid = if admission_version.nil?
        values.all?(&:nil?)
      else
        values.none?(&:nil?) && preflight_checked_at >= requested_at &&
          (admitted_at.nil? || preflight_checked_at <= admitted_at)
      end
      errors.add(:admission_version, "does not match admission provenance") unless valid
    end

    def dispatch_consistency
      attempted = dispatch_attempt_count.positive? ? dispatch_attempted_at.present? : true
      enqueued = if dispatch_enqueued_at
        dispatch_attempted_at.present? && dispatch_enqueued_at >= dispatch_attempted_at &&
          dispatch_last_error_category.nil?
      else
        true
      end
      errors.add(:dispatch_attempt_count, "does not match dispatch evidence") unless attempted && enqueued
    end

    def throttle_observation_consistency
      values = [ throttled_at, throttle_reason ]
      valid = values.all?(&:nil?) && throttle_until.nil?
      valid ||= values.all?(&:present?) && (throttle_until.nil? || throttle_until >= throttled_at)
      errors.add(:throttled_at, "does not match throttle observation") unless valid
    end
  end
end
