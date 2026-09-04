# frozen_string_literal: true

require "digest"

module Billing
  class WebhookEvent < ApplicationRecord
    self.table_name = "billing_webhook_events"

    STATES = %w[pending processing processed retryable dead_letter].freeze
    RESULTS = %w[applied stale observed ignored].freeze
    ENVIRONMENTS = %w[development test staging production].freeze

    validates :provider, format: { with: ValueNormalization::PROVIDER_PATTERN }
    validates :environment, inclusion: { in: ENVIRONMENTS }
    validates :provider_event_id, format: { with: ValueNormalization::REFERENCE_PATTERN }
    validates :event_type, format: { with: ValueNormalization::KEY_PATTERN }
    validates :payload_checksum, format: { with: /\A[0-9a-f]{64}\z/ }
    validates :payload_ciphertext, presence: true, length: { maximum: 1_048_576 }
    validates :request_headers, presence: true
    validates :state, inclusion: { in: STATES }
    validates :processing_result, inclusion: { in: RESULTS }, allow_nil: true
    validates :parser_version, numericality: { only_integer: true, in: 1..32_767 }
    validates :attempt_count, :duplicate_count, :conflict_count, :replay_count,
      numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :received_at, :last_received_at, presence: true
    validates :last_error_category, format: { with: ValueNormalization::KEY_PATTERN }, allow_nil: true
    validate :request_headers_are_bounded
    validate :receive_order
    validate :tenant_projection_shape
    validate :lifecycle_shape

    scope :actionable, -> { where(state: %w[pending retryable]) }

    def payload(cipher: WebhookPayloadCipher.new)
      body = cipher.decrypt(payload_ciphertext)
      raise WebhookPayloadCorrupt unless ActiveSupport::SecurityUtils.secure_compare(
        Digest::SHA256.hexdigest(body), payload_checksum
      )

      body
    end

    def summary
      WebhookEventSummary.new(
        id: id,
        provider: provider,
        event_type: event_type,
        state: state,
        received_at: received_at,
        attempt_count: attempt_count,
        duplicate_count: duplicate_count,
        conflict_count: conflict_count,
        replay_count: replay_count,
        processing_result: processing_result,
        last_error_category: last_error_category,
        organization_id: organization_id,
        subscription_id: subscription_id
      )
    end

    def begin_attempt!(at: Time.current)
      assign_attributes(
        state: "processing", attempt_count: attempt_count + 1, last_attempted_at: at,
        processed_at: nil, failed_at: nil, last_error_category: nil,
        processing_result: nil, next_attempt_at: nil
      )
      save!
    end

    def complete_projection!(result:, at: Time.current, organization_id: nil, subscription_id: nil)
      assign_attributes(
        state: "processed", processing_result: result, organization_id: organization_id,
        subscription_id: subscription_id, processed_at: at, failed_at: nil,
        last_error_category: nil, next_attempt_at: nil
      )
      save!
    end

    def fail_projection!(category:, retryable:, at: Time.current, retry_at: nil)
      assign_attributes(
        state: retryable ? "retryable" : "dead_letter", processing_result: nil,
        processed_at: nil, failed_at: at, last_error_category: category,
        next_attempt_at: retryable ? retry_at : nil
      )
      save!
    end

    def prepare_replay!(at: Time.current)
      assign_attributes(
        state: "pending", replay_count: replay_count + 1, processing_result: nil,
        processed_at: nil, failed_at: nil, last_error_category: nil,
        next_attempt_at: nil, updated_at: at
      )
      save!
    end

    def inspect
      "#<#{self.class.name} id=#{id.inspect} provider=#{provider.inspect} event_type=#{event_type.inspect} " \
        "state=#{state.inspect} provider_event_id=[FILTERED] payload=[FILTERED]>"
    end

    private

    def request_headers_are_bounded
      ValueNormalization.metadata(request_headers)
    rescue ArgumentError
      errors.add(:request_headers, "must contain bounded safe metadata")
    end

    def receive_order
      return unless received_at && last_received_at && last_received_at < received_at

      errors.add(:last_received_at, "cannot precede first receipt")
    end

    def tenant_projection_shape
      if subscription_id.present? && organization_id.blank?
        errors.add(:subscription_id, "requires an organization")
      end
      return unless subscription_id.present? && organization_id.present?

      linked = Subscription.where(id: subscription_id, organization_id: organization_id).exists?
      errors.add(:subscription_id, "must belong to the projected organization") unless linked
    end

    def lifecycle_shape
      valid = case state
      when "pending"
        pending_attempt_shape? && processed_at.nil? && failed_at.nil? &&
          last_error_category.nil? && processing_result.nil?
      when "processing"
        attempt_count.positive? && last_attempted_at.present? && processed_at.nil? &&
          failed_at.nil? && last_error_category.nil? && processing_result.nil? && next_attempt_at.nil?
      when "processed"
        attempt_count.positive? && last_attempted_at.present? && processed_at.present? &&
          failed_at.nil? && last_error_category.nil? && processing_result.present? && next_attempt_at.nil?
      when "retryable"
        attempt_count.positive? && last_attempted_at.present? && processed_at.nil? &&
          failed_at.present? && last_error_category.present? && processing_result.nil? && next_attempt_at.present?
      when "dead_letter"
        attempt_count.positive? && last_attempted_at.present? && processed_at.nil? &&
          failed_at.present? && last_error_category.present? && processing_result.nil? && next_attempt_at.nil?
      else
        false
      end
      errors.add(:state, "does not match webhook lifecycle") unless valid
    end

    def pending_attempt_shape?
      (attempt_count.zero? && last_attempted_at.nil?) ||
        (attempt_count.positive? && last_attempted_at.present? && replay_count.positive?)
    end
  end
end
