# frozen_string_literal: true

module Auditing
  class AuditQuery
    PAGE_SIZE = 50
    MAX_PAGE = 10_000
    FILTERS = %w[action actor_membership_id result target_type].freeze

    def call(organization_id:, filters: {}, page: nil)
      relation = AuditEvent.where(organization_id: organization_id)
      normalized_filters(filters).each do |key, value|
        relation = relation.where(key => value)
      end
      number = normalize_page(page)
      total_count = relation.count
      records = relation.order(occurred_at: :desc, id: :desc)
        .offset((number - 1) * PAGE_SIZE).limit(PAGE_SIZE).to_a
      AuditPage.new(records: records, number: number, page_size: PAGE_SIZE, total_count: total_count)
    end

    private

    def normalized_filters(filters)
      filters.to_h.stringify_keys.slice(*FILTERS).each_with_object({}) do |(key, raw), output|
        value = raw.to_s.strip
        next if value.blank?
        next unless filter_valid?(key, value)

        output[key] = value
      end
    end

    def filter_valid?(key, value)
      case key
      when "action" then AuditEvent::ACTION_PATTERN.match?(value)
      when "actor_membership_id" then Shared::Public.application_uuid?(value)
      when "result" then AuditEvent::RESULTS.include?(value)
      when "target_type" then AuditEvent::TARGET_TYPE_PATTERN.match?(value)
      end
    end

    def normalize_page(value)
      Integer(value || 1).clamp(1, MAX_PAGE)
    rescue ArgumentError, TypeError
      1
    end
  end
end
