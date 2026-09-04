# frozen_string_literal: true

require "openssl"

module Tenancy
  class InvitationRateLimiter
    Rule = Data.define(:limit, :window)
    DEFAULTS = {
      "issue_actor" => Rule.new(20, 1.hour),
      "issue_destination" => Rule.new(5, 1.hour),
      "accept_ip" => Rule.new(30, 1.hour)
    }.freeze

    def initialize(rules: DEFAULTS, clock: -> { Time.current })
      @rules = rules.transform_keys(&:to_s).freeze
      @clock = clock
      validate_rules!
    end

    def consume!(scope:, key:)
      scope = scope.to_s
      rule = @rules.fetch(scope)
      now = @clock.call
      started_at = Time.at((now.to_i / rule.window.to_i) * rule.window.to_i).utc
      expires_at = started_at + rule.window
      digest = key_digest(scope, key)
      sql = <<~SQL.squish
        INSERT INTO invitation_rate_limit_buckets
          (scope, key_digest, window_started_at, expires_at, request_count, created_at, updated_at)
        VALUES (?, ?, ?, ?, 1, ?, ?)
        ON CONFLICT (scope, key_digest, window_started_at)
        DO UPDATE SET request_count = invitation_rate_limit_buckets.request_count + 1,
          expires_at = GREATEST(invitation_rate_limit_buckets.expires_at, EXCLUDED.expires_at),
          updated_at = EXCLUDED.updated_at
        RETURNING invitation_rate_limit_buckets.*
      SQL
      bucket = InvitationRateLimitBucket.uncached do
        InvitationRateLimitBucket.find_by_sql([ sql, scope, digest, started_at, expires_at, now, now ]).sole
      end
      raise InvitationRateLimited.new(retry_after: (expires_at - now).ceil) if bucket.request_count > rule.limit

      bucket
    rescue KeyError
      raise ArgumentError, "unsupported invitation rate-limit scope"
    end

    private

    def validate_rules!
      unknown = @rules.keys - InvitationRateLimitBucket::SCOPES
      valid = unknown.empty? && @rules.values.all? do |rule|
        rule.is_a?(Rule) && rule.limit.is_a?(Integer) && rule.limit.positive? &&
          rule.window.respond_to?(:to_i) && rule.window.to_i.positive?
      end
      raise ArgumentError, "invalid invitation rate-limit rules" unless valid
    end

    def key_digest(scope, key)
      value = key.to_s
      raise ArgumentError, "invitation rate-limit key is invalid" unless value.bytesize.between?(1, 1024)

      secret = Rails.application.key_generator.generate_key("tenancy/invitation-rate-limit/v1", 32)
      OpenSSL::HMAC.hexdigest("SHA256", secret, "#{scope}:#{value}")
    end
  end
end
