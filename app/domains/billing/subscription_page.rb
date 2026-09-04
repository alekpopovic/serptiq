# frozen_string_literal: true

module Billing
  SubscriptionPage = Data.define(:subscriptions, :next_page, :total) do
    def initialize(subscriptions:, next_page:, total:)
      items = Array(subscriptions)
      unless items.length <= 100 && items.all? { |item| item.is_a?(SubscriptionSnapshot) }
        raise ArgumentError, "subscription page items are invalid"
      end
      unless next_page.nil? || (next_page.is_a?(Integer) && next_page.positive?)
        raise ArgumentError, "subscription next page is invalid"
      end
      unless total.is_a?(Integer) && total >= items.length
        raise ArgumentError, "subscription page total is invalid"
      end

      super(subscriptions: items.freeze, next_page: next_page, total: total)
      freeze
    end

    def as_json(*)
      { count: subscriptions.length, next_page: next_page, total: total }.compact.freeze
    end
  end
end
