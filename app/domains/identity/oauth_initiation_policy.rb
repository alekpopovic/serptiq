# frozen_string_literal: true

module Identity
  class OauthInitiationPolicy
    attr_reader :transaction_ttl, :retention, :rate_window, :max_per_ip, :max_per_session,
      :max_open_per_ip, :max_open_per_session

    def self.from_settings(settings: Rails.application.config.x.searchops)
      new(
        transaction_ttl: settings.fetch(:oauth_transaction_ttl),
        retention: settings.fetch(:oauth_transaction_retention),
        rate_window: settings.fetch(:oauth_start_rate_window),
        max_per_ip: settings.fetch(:oauth_start_max_per_ip),
        max_per_session: settings.fetch(:oauth_start_max_per_session),
        max_open_per_ip: settings.fetch(:oauth_start_max_open_per_ip),
        max_open_per_session: settings.fetch(:oauth_start_max_open_per_session)
      )
    end

    def initialize(transaction_ttl:, retention:, rate_window:, max_per_ip:, max_per_session:,
      max_open_per_ip:, max_open_per_session:)
      @transaction_ttl = transaction_ttl
      @retention = retention
      @rate_window = rate_window
      @max_per_ip = max_per_ip
      @max_per_session = max_per_session
      @max_open_per_ip = max_open_per_ip
      @max_open_per_session = max_open_per_session
      validate!
      freeze
    end

    private

    def validate!
      durations = [ transaction_ttl, retention, rate_window ]
      counts = [ max_per_ip, max_per_session, max_open_per_ip, max_open_per_session ]
      valid = durations.all? { |value| value.is_a?(Numeric) && value.positive? } &&
        transaction_ttl <= OauthTransaction::MAX_LIFETIME && retention >= transaction_ttl &&
        counts.all? { |value| value.is_a?(Integer) && value.positive? }
      raise ArgumentError, "OAuth initiation policy is invalid" unless valid
    end
  end
end
