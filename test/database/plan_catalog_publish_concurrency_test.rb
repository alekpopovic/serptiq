# frozen_string_literal: true

require "test_helper"

class PlanCatalogPublishConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    truncate_records
    Plans::Public.sync_catalog
    @publisher = create_identity_user(display_name: "Concurrent Catalog Publisher")
    Plans::CatalogAccessGrant.create!(
      user_id: @publisher.id,
      permission: "plan_catalog.publish",
      granted_at: Time.current
    )
    @authorization = Plans::Public.authorize_catalog!(
      user: @publisher,
      permission: "plan_catalog.publish"
    )
    publish_catalog_version(plan_key: "starter", version: 1, authorization: @authorization)
    @catalog_directory, @catalog_path = version_two_catalog
    Plans::Public.sync_catalog(path: @catalog_path)
  end

  teardown do
    truncate_records
    FileUtils.remove_entry(@catalog_directory) if @catalog_directory&.exist?
  end

  test "competing publication attempts serialize on the plan version sequence" do
    definition = Plans::Public.validate_catalog(path: @catalog_path).definitions
      .find { |candidate| candidate.key == "starter" }
    outcomes = run_concurrently(2.times.map do
      -> {
        Plans::Public.publish_version(
          path: @catalog_path,
          plan_key: "starter",
          version: 2,
          expected_previous_version: 1,
          catalog_checksum: definition.checksum,
          effective_at: nil,
          confirmation: "PUBLISH starter VERSION 2 AFTER 1",
          authorization: @authorization
        )
        "published"
      }
    end)

    assert_equal 1, outcomes.count("published"), outcomes.inspect
    assert_equal 1, outcomes.count("plan_version_not_draft"), outcomes.inspect
    assert_empty outcomes.grep(/unexpected/)
    assert_equal "published", catalog_version.reload.status
    assert_equal 1, Auditing::AuditEvent.where(
      action: "plan.version_published",
      target_id: catalog_version.id,
      result: "succeeded"
    ).count
  end

  private

  def run_concurrently(operations)
    ready = Queue.new
    start = Queue.new
    outcomes = Queue.new
    threads = operations.map do |operation|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          outcomes << operation.call
        rescue Shared::Public::ConflictError => error
          outcomes << error.reason_code
        rescue StandardError => error
          outcomes << "unexpected:#{error.class.name}:#{error.message}"
        end
      end
    end
    operations.length.times { ready.pop }
    operations.length.times { start << true }
    threads.each(&:join)
    operations.length.times.map { outcomes.pop }
  end

  def version_two_catalog
    document = YAML.safe_load_file(Plans::Catalog::DEFAULT_PATH, permitted_classes: [ Date ], aliases: false)
    starter = document.fetch("plans").find { |row| row.fetch("key") == "starter" }
    starter["version"] = 2
    starter["monthly_price_eur"] = 45
    directory = Pathname(Dir.mktmpdir("concurrent-catalog"))
    path = directory.join("plans.yml")
    path.write(YAML.dump(document))
    [ directory, path ]
  end

  def catalog_version
    Plans::PlanVersion.joins(:plan).find_by!(plans: { key: "starter" }, version: 2)
  end

  def truncate_records
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE plans, organizations, users CASCADE")
  end
end
