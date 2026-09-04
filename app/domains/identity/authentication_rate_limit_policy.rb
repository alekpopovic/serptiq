# frozen_string_literal: true

module Identity
  class AuthenticationRateLimitPolicy
    Rule = Data.define(:limit, :window)

    SCOPES = %w[
      oauth_start_ip
      oauth_link_session
      oauth_callback_failure_ip
      session_action_session
      account_security_session
    ].freeze

    def self.from_settings(settings: Rails.application.config.x.searchops)
      new(rules: {
        "oauth_start_ip" => Rule.new(
          settings.fetch(:oauth_start_max_per_ip),
          settings.fetch(:oauth_start_rate_window)
        ),
        "oauth_link_session" => Rule.new(
          settings.fetch(:oauth_start_max_per_session),
          settings.fetch(:oauth_start_rate_window)
        ),
        "oauth_callback_failure_ip" => Rule.new(
          settings.fetch(:auth_callback_failure_max_per_ip),
          settings.fetch(:auth_callback_failure_rate_window)
        ),
        "session_action_session" => Rule.new(
          settings.fetch(:auth_session_action_max_per_session),
          settings.fetch(:auth_session_action_rate_window)
        ),
        "account_security_session" => Rule.new(
          settings.fetch(:auth_account_security_max_per_session),
          settings.fetch(:auth_account_security_rate_window)
        )
      })
    end

    def self.for_oauth(policy)
      new(rules: {
        "oauth_start_ip" => Rule.new(policy.max_per_ip, policy.rate_window),
        "oauth_link_session" => Rule.new(policy.max_per_session, policy.rate_window)
      })
    end

    def initialize(rules:)
      @rules = rules.to_h.transform_keys(&:to_s).transform_values do |rule|
        Rule.new(rule.limit, rule.window)
      end.freeze
      validate!
      freeze
    end

    def fetch(scope)
      @rules.fetch(scope.to_s)
    rescue KeyError
      raise ArgumentError, "unsupported authentication rate-limit scope"
    end

    private

    def validate!
      valid_scopes = @rules.keys.present? && (@rules.keys - SCOPES).empty?
      valid_rules = @rules.values.all? do |rule|
        rule.limit.is_a?(Integer) && rule.limit.positive? &&
          rule.window.is_a?(Numeric) && rule.window.between?(1.second, 1.day)
      end
      raise ArgumentError, "authentication rate-limit policy is invalid" unless valid_scopes && valid_rules
    end
  end
end
