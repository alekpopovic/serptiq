# frozen_string_literal: true

module Crawling
  RobotsGroup = Data.define(:agents, :rules) do
    def initialize(agents:, rules:)
      normalized_agents = Array(agents).map { |value| value.to_s.freeze }.uniq.freeze
      normalized_rules = Array(rules).map do |value|
        value.is_a?(RobotsRule) ? value : RobotsRule.new(**value.to_h.symbolize_keys)
      end.freeze
      raise ArgumentError, "robots group requires an agent" if normalized_agents.empty?

      super(agents: normalized_agents, rules: normalized_rules)
      freeze
    end

    def as_json(*)
      { "agents" => agents, "rules" => rules.map(&:as_json) }
    end
  end
end
