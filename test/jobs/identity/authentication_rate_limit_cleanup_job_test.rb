# frozen_string_literal: true

require "test_helper"

class IdentityAuthenticationRateLimitCleanupJobTest < ActiveJob::TestCase
  test "maintenance cleanup deletes only expired buckets" do
    now = Time.current.change(usec: 0)
    expired = create_bucket(window_started_at: now - 2.minutes, expires_at: now - 1.minute)
    active = create_bucket(
      key_digest: "b" * 64,
      window_started_at: now,
      expires_at: now + 1.minute
    )

    travel_to(now) do
      assert_equal 1, Identity::AuthenticationRateLimitCleanupJob.perform_now
    end

    refute Identity::AuthenticationRateLimitBucket.exists?(expired.id)
    assert Identity::AuthenticationRateLimitBucket.exists?(active.id)
    assert_equal "maintenance", Identity::AuthenticationRateLimitCleanupJob.new.queue_name
    assert_equal 50, Identity::AuthenticationRateLimitCleanupJob.new.priority
  end

  private

  def create_bucket(key_digest: "a" * 64, window_started_at:, expires_at:)
    Identity::AuthenticationRateLimitBucket.create!(
      scope: "oauth_callback_failure_ip",
      key_digest: key_digest,
      window_started_at: window_started_at,
      expires_at: expires_at,
      request_count: 1
    )
  end
end
