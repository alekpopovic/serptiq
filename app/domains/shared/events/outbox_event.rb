# frozen_string_literal: true

module Shared
  module Events
    class OutboxEvent < ApplicationRecord
      self.table_name = "outbox_events"

      TYPE_PATTERN = /\A[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+\z/
      AGGREGATE_PATTERN = /\A[A-Z][A-Za-z0-9]{0,47}\z/
      DIGEST_PATTERN = /\A[0-9a-f]{64}\z/

      validates :organization_id, :aggregate_id, :occurred_at, presence: true
      validates :aggregate_type, format: { with: AGGREGATE_PATTERN }
      validates :event_type, format: { with: TYPE_PATTERN }
      validates :event_version, numericality: { only_integer: true, greater_than: 0 }
      validates :attempt_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
      validates :idempotency_key, format: { with: DIGEST_PATTERN }
      validates :last_error_category, format: { with: /\A[a-z][a-z0-9_]{0,63}\z/ }, allow_nil: true
      validate :identifier_shapes
      validate :payload_shape
      validate :publish_shape

      scope :unpublished, -> { where(published_at: nil) }

      def published?
        published_at.present?
      end

      private

      def identifier_shapes
        %i[organization_id aggregate_id].each do |attribute|
          errors.add(attribute, "is invalid") unless Shared::Public.application_uuid?(public_send(attribute))
        end
      end

      def payload_shape
        valid = payload.is_a?(Hash) && JSON.generate(payload).bytesize <= 8.kilobytes
        errors.add(:payload, "must be a bounded object") unless valid
      end

      def publish_shape
        valid = published_at.nil? || (last_attempted_at.present? && last_error_category.nil?)
        errors.add(:published_at, "does not match publish state") unless valid
      end
    end
  end
end
