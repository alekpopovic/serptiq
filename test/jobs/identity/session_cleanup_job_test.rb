# frozen_string_literal: true

require "test_helper"

class IdentitySessionCleanupJobTest < ActiveJob::TestCase
  test "maintenance job deletes only unreferenced sessions beyond retention" do
    now = Time.current.change(usec: 0)
    deletable = issue_identity_session(at: now - 200.days).session
    retained_recent = issue_identity_session(at: now - 20.days).session
    protected = issue_identity_session(at: now - 200.days).session
    create_oauth_transaction(link_session: protected, expires_at: 10.minutes.from_now)

    assert_difference -> { Identity::Session.count } => -1 do
      Identity::SessionCleanupJob.perform_now
    end

    refute Identity::Session.exists?(deletable.id)
    assert Identity::Session.exists?(retained_recent.id)
    assert Identity::Session.exists?(protected.id), "OAuth link-session references are retained"
    assert_equal "maintenance", Identity::SessionCleanupJob.new.queue_name
    assert_equal 50, Identity::SessionCleanupJob.new.priority
  end
end
