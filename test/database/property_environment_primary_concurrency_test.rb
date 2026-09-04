# frozen_string_literal: true

require "test_helper"

class PropertyEnvironmentPrimaryConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    truncate_records
    Current.reset
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "environment-primary-concurrency")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "environment-primary-project")
    @property = create_property_for(@owner, project: @project)
    @candidates = 2.times.map do |index|
      Properties::Public.create_environment(
        actor_membership: @owner.membership,
        project_id: @project.id,
        property_id: @property.id,
        key: "production-#{index}",
        kind: "production",
        display_name: "Production #{index}",
        origin: "https://production-#{index}.example.com"
      )
    end
  end

  teardown do
    Current.reset
    truncate_records
  end

  test "property row lock serializes concurrent primary selection" do
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    threads = @candidates.map do |environment|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Current.reset
          ready << true
          start.pop
          Properties::Public.update_environment(
            actor_membership: @owner.membership,
            project_id: @project.id,
            property_id: @property.id,
            environment_id: environment.id,
            display_name: environment.display_name,
            origin: environment.origin,
            primary: true
          )
          results << "updated"
        rescue StandardError => error
          results << "#{error.class.name}:#{error.message}"
        ensure
          Current.reset
        end
      end
    end
    @candidates.length.times { ready.pop }
    @candidates.length.times { start << true }
    threads.each(&:join)

    outcomes = @candidates.length.times.map { results.pop }
    assert_equal [ "updated", "updated" ], outcomes.sort, outcomes.inspect
    primary = Properties::Environment.where(property_id: @property.id, primary: true, status: "active").sole
    assert_includes @candidates.map(&:id), primary.id
    assert_equal primary.origin, @property.website_property_config.reload.origin
  end

  private

  def truncate_records
    ActiveRecord::Base.connection.execute(
      "TRUNCATE TABLE property_environments, website_property_configs, android_property_configs, " \
        "ios_property_configs, properties, entitlement_definitions, plans, organizations, users, " \
        "audit_events CASCADE"
    )
  end
end
