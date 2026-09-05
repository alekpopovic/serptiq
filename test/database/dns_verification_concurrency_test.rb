# frozen_string_literal: true

require "test_helper"

class DnsVerificationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  class BlockingAdapter
    attr_reader :calls

    def initialize(entered:, release:, result:)
      @entered = entered
      @release = release
      @result = result
      @calls = Queue.new
    end

    def method
      "dns_txt"
    end

    def verify(challenge:, expected_value:)
      calls << [ challenge.id, expected_value ]
      @entered << true
      @release.pop
      @result
    end
  end

  setup do
    truncate_records
    Current.reset
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "dns-verification-concurrency")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "dns-concurrency-project")
    @property = create_property_for(@owner, project: @project)
    @environment = @property.environments.sole
    @now = Time.zone.parse("2026-09-04 12:00:00")
    @challenge = Verification::Public.issue_challenge(
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: @property.id,
      environment_id: @environment.id,
      method: "dns_txt",
      clock: -> { @now }
    ).challenge
  end

  teardown do
    Current.reset
    truncate_records
  end

  test "concurrent successful observations consume one challenge once and replay is inert" do
    entered = Queue.new
    release = Queue.new
    adapter = BlockingAdapter.new(
      entered: entered,
      release: release,
      result: Verification::AdapterResult.new(
        verified: true, evidence: { matched: true, record_count: 1 }
      )
    )
    registry = Verification::AdapterRegistry.new(adapters: { "dns_txt" => adapter })
    results = Queue.new
    build_thread = lambda do |at|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          result = Verification::AttemptChallenge.new(clock: -> { at }, registry: registry).call(
            actor_membership: @owner.membership,
            project_id: @project.id,
            property_id: @property.id,
            environment_id: @environment.id,
            challenge_id: @challenge.id
          )
          results << result
        rescue StandardError => error
          results << error
        ensure
          Current.reset
        end
      end
    end
    threads = [ build_thread.call(@now + 1.minute) ]
    entered.pop
    threads << build_thread.call(@now + 2.minutes)
    entered.pop
    2.times { release << true }
    threads.each(&:join)

    outcomes = 2.times.map { results.pop }
    assert outcomes.none?(Exception), outcomes.inspect
    assert_equal 1, outcomes.count(&:changed?)
    assert @challenge.reload.verified?
    assert_equal 2, @challenge.attempt_count
    assert_equal 1, @challenge.attempts.count
    assert_equal "verified", @challenge.attempts.sole.outcome

    replay = Verification::AttemptChallenge.new(
      clock: -> { @now + 3.minutes }, registry: registry
    ).call(
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: @property.id,
      environment_id: @environment.id,
      challenge_id: @challenge.id
    )
    refute replay.changed?
    assert_equal 2, adapter.calls.size
  ensure
    2.times { release << true }
    threads&.each(&:join)
  end

  private

  def truncate_records
    ActiveRecord::Base.connection.execute(
      "TRUNCATE TABLE entitlement_definitions, plans, organizations, users, " \
        "audit_events, outbox_events CASCADE"
    )
  end
end
