# frozen_string_literal: true

module Verification
  ChallengeSummary = Data.define(
    :id, :method, :state, :attempt_count, :attempted_at, :verified_at, :expires_at,
    :failure_category, :instructions, :attempts, :provider_property_identifier,
    :provider_permission_level, :provider_checked_at
  ) do
    def initialize(**attributes)
      %i[id method state].each { |name| attributes[name] = attributes.fetch(name).to_s.freeze }
      attributes[:failure_category] = attributes[:failure_category]&.to_s&.freeze
      attributes[:provider_property_identifier] = attributes[:provider_property_identifier]&.to_s&.freeze
      attributes[:provider_permission_level] = attributes[:provider_permission_level]&.to_s&.freeze
      attributes[:attempts] = Array(attributes[:attempts]).freeze
      super(**attributes)
      freeze
    end

    Challenge::STATES.each do |value|
      define_method("#{value}?") { state == value }
    end
  end
end
