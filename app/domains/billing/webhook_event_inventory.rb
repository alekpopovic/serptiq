# frozen_string_literal: true

module Billing
  class WebhookEventInventory
    def call(state: nil, limit: 50)
      bounded_limit = Integer(limit.to_s, 10)
      raise ArgumentError, "webhook event limit is invalid" unless bounded_limit.between?(1, 100)
      if state.present? && !WebhookEvent::STATES.include?(state.to_s)
        raise ArgumentError, "webhook event state is invalid"
      end

      relation = WebhookEvent.order(received_at: :desc, id: :desc)
      relation = relation.where(state: state.to_s) if state.present?
      relation.limit(bounded_limit).map(&:summary).freeze
    rescue ArgumentError => error
      raise error if error.message.start_with?("webhook event")

      raise ArgumentError, "webhook event limit is invalid"
    end
  end
end
