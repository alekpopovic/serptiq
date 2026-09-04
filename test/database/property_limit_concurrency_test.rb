# frozen_string_literal: true

require "test_helper"

class PropertyLimitConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    truncate_records
    Current.reset
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "property-limit-concurrency")
    enable_project_limit(@owner)
    enable_property_limits(@owner, website: 1, mobile: 1)
    @project = create_project_for(@owner, slug: "property-limit-race")
  end

  teardown do
    Current.reset
    truncate_records
  end

  test "PostgreSQL group lock admits only one concurrent website-family property" do
    outcomes = concurrently(2.times.map do |index|
      -> {
        Properties::Public.create_property(
          actor_membership: @owner.membership,
          project_id: @project.id,
          kind: index.zero? ? "website" : "web_application",
          display_name: "Racing Property #{index}",
          configuration: { origin: "https://race-#{index}.example.com" }
        )
        "created"
      }
    end)

    assert_equal 1, outcomes.count("created"), outcomes.inspect
    assert_equal 1, outcomes.count("property_limit_reached"), outcomes.inspect
    assert_empty outcomes.grep(/unexpected/)
    assert_equal 1, Properties::Property.active.count
    assert_equal 1, Authorization::ScopeReference.where(scope_type: "Property").count
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
        rescue Properties::PropertyLimitReached => error
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
      "TRUNCATE TABLE website_property_configs, android_property_configs, ios_property_configs, " \
        "properties, entitlement_definitions, plans, organizations, users, audit_events CASCADE"
    )
  end
end
