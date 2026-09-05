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
    FAILURE_CATEGORY_PATTERN = /\A[a-z][a-z0-9_]{0,63}\z/
    VERSION_PATTERN = /\A[A-Za-z0-9][A-Za-z0-9._+-]{0,63}\z/
    IMMUTABLE_INPUTS = %i[
      organization_id project_id property_id environment_id scan_type initiator_type
      initiated_by_membership_id settings_snapshot settings_digest entitlement_snapshot
      entitlement_digest engine_version rule_set_version configuration_version release_id
      baseline_scan_id requested_at
    ].freeze

    has_many :events, class_name: "Crawling::ScanEvent", inverse_of: :scan,
      dependent: :restrict_with_exception
    has_one :policy_snapshot, class_name: "Crawling::PolicySnapshot", inverse_of: false,
      dependent: :restrict_with_exception
    belongs_to :baseline_scan, class_name: "Crawling::Scan", optional: true

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
    validate :identifier_shapes
    validate :initiator_shape
    validate :snapshots_are_bounded_objects
    validate :snapshot_digests_match
    validate :counter_consistency
    validate :lifecycle_consistency
    validate :inputs_are_immutable, on: :update

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

    def counters
      ScanCounters.new(**SCAN_COUNTER_ATTRIBUTES.to_h { |name| [ name, public_send(name) ] })
    end

    def finished_at
      completed_at || canceled_at || failed_at
    end

    private

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
  end
end
