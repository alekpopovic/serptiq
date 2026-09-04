# frozen_string_literal: true

require "digest"

module Billing
  class WebhookEvent < ApplicationRecord
    self.table_name = "billing_webhook_events"

    STATES = %w[pending processing processed retryable dead_letter].freeze
    ENVIRONMENTS = %w[development test staging production].freeze

    validates :provider, format: { with: ValueNormalization::PROVIDER_PATTERN }
    validates :environment, inclusion: { in: ENVIRONMENTS }
    validates :provider_event_id, format: { with: ValueNormalization::REFERENCE_PATTERN }
    validates :event_type, format: { with: ValueNormalization::KEY_PATTERN }
    validates :payload_checksum, format: { with: /\A[0-9a-f]{64}\z/ }
    validates :payload_ciphertext, presence: true, length: { maximum: 1_048_576 }
    validates :request_headers, presence: true
    validates :state, inclusion: { in: STATES }
    validates :attempt_count, :duplicate_count, :conflict_count,
      numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :received_at, :last_received_at, presence: true
    validates :last_error_category, format: { with: ValueNormalization::KEY_PATTERN }, allow_nil: true
    validate :request_headers_are_bounded
    validate :receive_order
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
        last_error_category: last_error_category
      )
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

    def lifecycle_shape
      valid = case state
      when "pending"
        attempt_count.zero? && last_attempted_at.nil? && processed_at.nil? &&
          failed_at.nil? && last_error_category.nil?
      when "processing"
        attempt_count.positive? && last_attempted_at.present? && processed_at.nil? &&
          failed_at.nil? && last_error_category.nil?
      when "processed"
        attempt_count.positive? && last_attempted_at.present? && processed_at.present? &&
          failed_at.nil? && last_error_category.nil?
      when "retryable", "dead_letter"
        attempt_count.positive? && last_attempted_at.present? && processed_at.nil? &&
          failed_at.present? && last_error_category.present?
      else
        false
      end
      errors.add(:state, "does not match webhook lifecycle") unless valid
    end
  end
end
