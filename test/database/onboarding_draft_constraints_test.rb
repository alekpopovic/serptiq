# frozen_string_literal: true

require "test_helper"

class OnboardingDraftConstraintsTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    truncate_records
    Current.reset
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "onboarding-db")
    enable_onboarding_entitlements(@owner)
  end

  teardown do
    Current.reset
    truncate_records
  end

  test "PostgreSQL lock returns one active draft for concurrent starts" do
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Current.reset
          ready << true
          start.pop
          draft = start_onboarding_draft(@owner)
          results << draft.id
        rescue StandardError => error
          results << "#{error.class}:#{error.message}"
        ensure
          Current.reset
        end
      end
    end
    2.times { ready.pop }
    2.times { start << true }
    threads.each(&:join)
    ids = 2.times.map { results.pop }

    assert_equal 1, ids.uniq.length, ids.inspect
    assert_equal 1, Onboarding::Draft.active.count
  end

  test "database rejects cross-tenant actors and malformed completed state" do
    draft = start_onboarding_draft(@owner)
    foreign = create_organization_for(slug: "onboarding-db-foreign")

    assert_raises(ActiveRecord::StatementInvalid) do
      Onboarding::Draft.transaction(requires_new: true) do
        Onboarding::Draft.insert!(draft.attributes.except("id").merge(
          "organization_id" => foreign.organization.id,
          "project_id" => SecureRandom.uuid,
          "website_property_id" => SecureRandom.uuid,
          "android_property_id" => SecureRandom.uuid,
          "ios_property_id" => SecureRandom.uuid,
          "project_release_key" => "prj_#{SecureRandom.hex(16)}"
        ))
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      Onboarding::Draft.transaction(requires_new: true) do
        draft.update_columns(state: "completed", completed_at: Time.current)
      end
    end
  end

  private

  def truncate_records
    ActiveRecord::Base.connection.execute(
      "TRUNCATE TABLE entitlement_definitions, plans, organizations, users, audit_events CASCADE"
    )
  end
end
