# frozen_string_literal: true

require "test_helper"

class VerificationDnsRecheckTest < ActiveSupport::TestCase
  FakeAdapter = Struct.new(:result, :calls, keyword_init: true) do
    def method
      "dns_txt"
    end

    def verify(challenge:, expected_value:)
      calls << { challenge_id: challenge.id, expected_value: expected_value }
      result
    end
  end

  setup do
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "dns-recheck")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "dns-recheck-project")
    @property = create_property_for(@owner, project: @project)
    @environment = @property.environments.sole
    @now = Time.zone.parse("2026-09-12 12:00:00")
    @challenge = issue_verified_challenge
  end

  test "successful due recheck renews observed freshness and records bounded evidence" do
    adapter = fake_adapter(verified: true, evidence: { matched: true, record_count: 1, token: "secret" })

    result = recheck(adapter: adapter)
    replay = recheck(adapter: adapter)

    assert result.changed?
    refute replay.changed?
    assert_equal @now, @challenge.reload.verified_at
    assert_equal @now + 30.days, @challenge.expires_at
    assert_equal 1, @challenge.attempt_count
    assert_equal 1, adapter.calls.length
    assert_equal "verified", @challenge.attempts.sole.outcome
    assert_equal({ "matched" => true, "record_count" => 1 }, @challenge.evidence)
    assert_equal [ "verified", @now ], @property.reload.values_at(:verification_status, :verified_at)
    assert Auditing::AuditEvent.exists?(
      action: "verification.recheck_succeeded", organization_id: @owner.organization.id
    )
    token = adapter.calls.sole.fetch(:expected_value)
    audit = Auditing::AuditEvent.find_by!(action: "verification.recheck_succeeded")
    event = Shared::Events::OutboxEvent.find_by!(event_type: "verification.recheck_succeeded")
    refute_includes audit.attributes.to_json, token
    refute_includes event.payload.to_json, token
    refute_includes event.payload.to_json, @challenge.expected_location
  end

  test "failed recheck retains the previous proof age and retries no sooner than policy" do
    adapter = fake_adapter(
      verified: false,
      failure_category: "dns_timeout",
      evidence: { record_count: 0 }
    )
    prior_verified_at = @challenge.verified_at

    first = recheck(adapter: adapter)
    immediate = recheck(adapter: adapter, at: @now + 1.hour)

    assert first.changed?
    refute immediate.changed?
    assert_equal prior_verified_at, @challenge.reload.verified_at
    assert_equal 1, adapter.calls.length
    assert_equal "dns_timeout", @challenge.attempts.sole.failure_category
    assert Auditing::AuditEvent.exists?(action: "verification.recheck_failed")
  end

  test "scheduler emits only explicit due tenant and challenge identifiers" do
    enqueued = []

    count = Verification::Public.schedule_dns_rechecks(
      clock: -> { @now },
      enqueue: ->(organization_id, challenge_id) { enqueued << [ organization_id, challenge_id ] }
    )

    assert_equal 1, count
    assert_equal [ [ @owner.organization.id, @challenge.id ] ], enqueued
  end

  test "recheck fails closed for a foreign tenant and a current origin mismatch" do
    foreign = create_organization_for(slug: "dns-recheck-foreign")
    adapter = fake_adapter(verified: true, evidence: { matched: true })

    foreign_result = Verification::Public.recheck_dns_challenge(
      organization_id: foreign.organization.id,
      challenge_id: @challenge.id,
      adapter: adapter,
      clock: -> { @now }
    )
    Properties::Environment.where(id: @environment.id).update_all(
      origin: "https://changed.example.com",
      host: "changed.example.com"
    )
    mismatch_result = recheck(adapter: adapter)

    refute foreign_result.changed?
    refute mismatch_result.changed?
    assert_empty adapter.calls
    assert_equal 0, Verification::Attempt.count
  end

  private

  def issue_verified_challenge
    challenge = Verification::Public.issue_challenge(
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: @property.id,
      environment_id: @environment.id,
      method: "dns_txt",
      clock: -> { @now - 8.days }
    ).challenge
    challenge.update!(
      state: "verified",
      verified_at: @now - 8.days,
      expires_at: @now + 22.days,
      evidence: { "matched" => true, "record_count" => 1 }
    )
    challenge
  end

  def fake_adapter(**result)
    FakeAdapter.new(result: Verification::AdapterResult.new(**result), calls: [])
  end

  def recheck(adapter:, at: @now)
    Verification::Public.recheck_dns_challenge(
      organization_id: @owner.organization.id,
      challenge_id: @challenge.id,
      adapter: adapter,
      clock: -> { at }
    )
  end
end
