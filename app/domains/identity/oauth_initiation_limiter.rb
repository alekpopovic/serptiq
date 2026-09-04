# frozen_string_literal: true

require "digest"

module Identity
  class OauthInitiationLimiter
    def initialize(policy:)
      @policy = policy
    end

    def within_limit(initiator_digest:, link_session:, now:)
      OauthTransaction.transaction do
        acquire_locks(initiator_digest, link_session)
        cleanup_stale_transactions(now)
        enforce_ip_limits!(initiator_digest, now)
        enforce_session_limits!(link_session, now) if link_session
        yield
      end
    end

    private

    def acquire_locks(initiator_digest, link_session)
      values = [ "ip:#{initiator_digest}" ]
      values << "session:#{link_session.id}" if link_session
      values.map { |value| advisory_key(value) }.sort.each do |key|
        OauthTransaction.connection.execute("SELECT pg_advisory_xact_lock(#{key})")
      end
    end

    def advisory_key(value)
      unsigned = Digest::SHA256.hexdigest("oauth-initiation:#{value}").first(16).to_i(16)
      unsigned >= (2**63) ? unsigned - (2**64) : unsigned
    end

    def cleanup_stale_transactions(now)
      cutoff = now - @policy.retention
      OauthTransaction.where("expires_at < ?", cutoff).or(
        OauthTransaction.where("consumed_at < ?", cutoff)
      ).delete_all
    end

    def enforce_ip_limits!(initiator_digest, now)
      scope = OauthTransaction.where(initiator_digest: initiator_digest)
      enforce_rate!(scope, now, @policy.max_per_ip, "oauth_start_ip_rate_limited")
      enforce_open!(scope, now, @policy.max_open_per_ip, "oauth_start_ip_outstanding_limited")
    end

    def enforce_session_limits!(link_session, now)
      scope = OauthTransaction.where(link_session_id: link_session.id, link_intent: true)
      enforce_rate!(scope, now, @policy.max_per_session, "oauth_start_session_rate_limited")
      enforce_open!(scope, now, @policy.max_open_per_session, "oauth_start_session_outstanding_limited")
    end

    def enforce_rate!(scope, now, maximum, reason_code)
      count = scope.where(created_at: (now - @policy.rate_window)..).count
      raise OauthInitiationLimited.new(reason_code: reason_code) if count >= maximum
    end

    def enforce_open!(scope, now, maximum, reason_code)
      count = scope.where(consumed_at: nil).where("expires_at > ?", now).count
      raise OauthInitiationLimited.new(reason_code: reason_code) if count >= maximum
    end
  end
end
