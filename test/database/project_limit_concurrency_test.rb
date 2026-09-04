# frozen_string_literal: true

require "test_helper"

class ProjectLimitConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    truncate_records
    Current.reset
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "project-limit-concurrency")
    enable_project_limit(@owner, limit: 1)
  end

  teardown do
    Current.reset
    truncate_records
  end

  test "PostgreSQL organization lock permits only one create at the active-project limit" do
    outcomes = concurrently(2.times.map do |index|
      -> {
        Projects::Public.create_project(
          actor_membership: @owner.membership,
          name: "Racing Project #{index}",
          slug: "racing-project-#{index}",
          description: "",
          default_locale: "en",
          time_zone: "UTC"
        )
        "created"
      }
    end)

    assert_equal 1, outcomes.count("created"), outcomes.inspect
    assert_equal 1, outcomes.count("project_limit_reached"), outcomes.inspect
    assert_empty outcomes.grep(/unexpected/)
    assert_equal 1, Projects::Project.active.count
    assert_equal 1, Authorization::ScopeReference.where(scope_type: "Project").count
  end

  private

  def concurrently(operations)
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    threads = operations.map do |operation|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Current.reset
          ready << true
          start.pop
          results << operation.call
        rescue Projects::ProjectLimitReached => error
          results << error.reason_code
        rescue StandardError => error
          results << "unexpected:#{error.class.name}:#{error.message}"
        ensure
          Current.reset
        end
      end
    end
    operations.length.times { ready.pop }
    operations.length.times { start << true }
    threads.each(&:join)
    operations.length.times.map { results.pop }
  end

  def truncate_records
    ActiveRecord::Base.connection.execute(
      "TRUNCATE TABLE entitlement_definitions, plans, organizations, users, audit_events CASCADE"
    )
  end
end
