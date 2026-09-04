# frozen_string_literal: true

require "test_helper"

class IdentityAuthenticationRateLimitBucketTest < ActiveSupport::TestCase
  test "validates bounded scope digest count and window" do
    bucket = Identity::AuthenticationRateLimitBucket.new(
      scope: "unknown",
      key_digest: "raw address",
      window_started_at: Time.current,
      expires_at: 1.minute.ago,
      request_count: 0
    )

    refute bucket.valid?
    assert bucket.errors.of_kind?(:scope, :inclusion)
    assert bucket.errors.of_kind?(:key_digest, :invalid)
    assert bucket.errors.of_kind?(:request_count, :greater_than)
    assert_includes bucket.errors[:expires_at], "must follow the window start"
  end

  test "PostgreSQL constraints reject invalid counter rows when validations are bypassed" do
    now = Time.current.change(usec: 0)
    valid = {
      scope: "oauth_start_ip",
      key_digest: "a" * 64,
      window_started_at: now,
      expires_at: now + 1.minute,
      request_count: 1,
      created_at: now,
      updated_at: now
    }

    assert_raises(ActiveRecord::StatementInvalid) do
      Identity::AuthenticationRateLimitBucket.transaction(requires_new: true) do
        Identity::AuthenticationRateLimitBucket.insert!(valid.merge(scope: "email_address"))
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Identity::AuthenticationRateLimitBucket.transaction(requires_new: true) do
        Identity::AuthenticationRateLimitBucket.insert!(valid.merge(request_count: 0))
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Identity::AuthenticationRateLimitBucket.transaction(requires_new: true) do
        Identity::AuthenticationRateLimitBucket.insert!(valid.merge(expires_at: now))
      end
    end
  end
end
