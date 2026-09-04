# frozen_string_literal: true

require "test_helper"

class VerificationChallengeLifecycleTest < ActiveSupport::TestCase
  FakeAdapter = Struct.new(:method, :result, :calls, keyword_init: true) do
    def verify(challenge:, expected_value:)
      calls << [ challenge.id, expected_value ]
      result
    end
  end

  setup do
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "verification-lifecycle")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "verification-project")
    @property = create_property_for(
      @owner,
      project: @project,
      configuration: { origin: "https://verify.example.com" }
    )
    @environment = @property.environments.sole
    @now = Time.zone.parse("2026-09-04 12:00:00")
  end

  test "issues a high entropy digest-bound challenge without persisting its exact value" do
    issued = issue(method: "dns_txt")
    challenge = issued.challenge
    value = issued.instructions.value

    assert challenge.pending?
    assert_equal "_searchops-verification.verify.example.com", challenge.expected_location
    assert_equal Digest::SHA256.hexdigest(value), challenge.challenge_digest
    assert_equal [ "pending", nil ], @property.reload.values_at(:verification_status, :verified_at)
    refute_includes challenge.attributes.to_json, value
    refute_includes Auditing::AuditEvent.find_by!(action: "verification.issued").attributes.to_json, value
    refute_includes Shared::Events::OutboxEvent.find_by!(event_type: "verification.issued").payload.to_json, value
    assert_operator value.bytesize, :>=, 60
  end

  test "successful verification is idempotent and projects an expiring property summary" do
    issued = issue(method: "dns_txt")
    adapter = fake_adapter(
      "dns_txt",
      Verification::AdapterResult.new(
        verified: true,
        evidence: { matched: true, record_count: 1, raw_token: issued.instructions.value }
      )
    )
    registry = Verification::AdapterRegistry.new(adapters: { "dns_txt" => adapter })
    service = Verification::AttemptChallenge.new(clock: -> { @now + 1.minute }, registry: registry)

    first = service.call(**attempt_attributes(issued.challenge))
    second = service.call(**attempt_attributes(issued.challenge))

    assert first.challenge.verified?
    refute second.changed?
    assert_equal 1, adapter.calls.length
    assert_equal 1, first.challenge.attempts.count
    assert_equal({ "matched" => true, "record_count" => 1 }, first.challenge.evidence)
    assert_equal [ "verified", @now + 1.minute ],
      @property.reload.values_at(:verification_status, :verified_at)
    assert_equal @now + 30.days + 1.minute, first.challenge.expires_at
  end

  test "five bounded failed attempts terminate the challenge and retain only safe evidence" do
    issued = issue(method: "html_file")
    adapter = fake_adapter(
      "html_file",
      Verification::AdapterResult.new(
        verified: false,
        failure_category: "proof_mismatch",
        evidence: { matched: false, status_code: 200, body: "hostile secret body" }
      )
    )
    registry = Verification::AdapterRegistry.new(adapters: { "html_file" => adapter })

    5.times do |index|
      at = @now + (index + 1).minutes
      Verification::AttemptChallenge.new(clock: -> { at }, registry: registry)
        .call(**attempt_attributes(issued.challenge))
    end

    challenge = issued.challenge.reload
    assert challenge.failed?
    assert_equal 5, challenge.attempt_count
    assert_equal 5, challenge.attempts.count
    assert_equal "proof_mismatch", challenge.failure_category
    assert_equal({ "matched" => false, "status_code" => 200 }, challenge.evidence)
    refute_includes challenge.attributes.to_json, "hostile secret body"
    assert_equal "failed", @property.reload.verification_status
    assert_equal 5, Auditing::AuditEvent.where(action: "verification.attempt_failed").count
  end

  test "expired challenge transitions without calling its adapter" do
    issued = issue(method: "meta_tag")
    adapter = fake_adapter(
      "meta_tag", Verification::AdapterResult.new(verified: true, evidence: { matched: true })
    )
    registry = Verification::AdapterRegistry.new(adapters: { "meta_tag" => adapter })

    result = Verification::AttemptChallenge.new(
      clock: -> { @now + 25.hours }, registry: registry
    ).call(**attempt_attributes(issued.challenge))

    assert result.challenge.expired?
    assert_empty adapter.calls
    assert_equal "expired", @property.reload.verification_status
    assert Auditing::AuditEvent.exists?(action: "verification.expired", target_id: issued.challenge.id)
  end

  test "revocation is idempotent and keeps prior success timestamp as history" do
    issued = issue(method: "html_file")
    issued.challenge.update!(
      state: "verified", verified_at: @now, expires_at: @now + 30.days
    )

    first = Verification::Public.revoke_challenge(**revoke_attributes(issued.challenge))
    second = Verification::Public.revoke_challenge(**revoke_attributes(issued.challenge))

    assert first.changed?
    refute second.changed?
    assert first.challenge.revoked?
    assert_equal @now, first.challenge.verified_at
    assert_equal 1, Auditing::AuditEvent.where(
      action: "verification.revoked", target_id: issued.challenge.id
    ).count
  end

  test "material origin update revokes exact bound proof and resets property summary" do
    issued = issue(method: "dns_txt")
    issued.challenge.update!(
      state: "verified", verified_at: @now, expires_at: @now + 30.days
    )
    @property.reload.update!(verification_status: "verified", verified_at: @now)

    Properties::Public.update_environment(
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: @property.id,
      environment_id: @environment.id,
      display_name: @environment.display_name,
      origin: "https://changed.example.com",
      primary: true
    )

    assert issued.challenge.reload.revoked?
    assert_equal "https://verify.example.com", issued.challenge.bound_origin
    assert_equal [ "unverified", nil ], @property.reload.values_at(:verification_status, :verified_at)
  end

  test "cross tenant and nested challenge identifiers fail closed" do
    issued = issue(method: "dns_txt")
    foreign = create_organization_for(slug: "verification-foreign")
    enable_project_limit(foreign)
    enable_property_limits(foreign)
    project = create_project_for(foreign, slug: "verification-foreign-project")
    property = create_property_for(foreign, project: project)

    assert_raises(Verification::AccessDenied) do
      Verification::Public.challenge_details(
        actor_membership: foreign.membership,
        project_id: project.id,
        property_id: property.id,
        environment_id: property.environments.sole.id,
        challenge_id: issued.challenge.id
      )
    end
    assert_raises(Verification::AccessDenied) do
      Verification::Public.revoke_challenge(
        actor_membership: foreign.membership,
        project_id: @project.id,
        property_id: @property.id,
        environment_id: @environment.id,
        challenge_id: issued.challenge.id
      )
    end
  end

  test "attempt interval is rate limited and audited without consuming another attempt" do
    issued = issue(method: "dns_txt")
    adapter = fake_adapter(
      "dns_txt",
      Verification::AdapterResult.new(
        verified: false, failure_category: "proof_missing", evidence: { record_count: 0 }
      )
    )
    registry = Verification::AdapterRegistry.new(adapters: { "dns_txt" => adapter })
    first_at = @now + 1.minute
    Verification::AttemptChallenge.new(clock: -> { first_at }, registry: registry)
      .call(**attempt_attributes(issued.challenge))

    error = assert_raises(Verification::RateLimited) do
      Verification::AttemptChallenge.new(clock: -> { first_at + 5.seconds }, registry: registry)
        .call(**attempt_attributes(issued.challenge))
    end

    assert_equal 25, error.retry_after
    assert_equal 1, issued.challenge.reload.attempt_count
    audit = Auditing::AuditEvent.where(
      action: "verification.attempt_failed", target_id: issued.challenge.id
    ).order(:created_at).last
    assert_equal "rate_limited", audit.metadata.fetch("failure_category")
  end

  test "freshness policy becomes stricter for high volume and render workloads" do
    issued = issue(method: "dns_txt")
    verified_at = @now - 2.days
    issued.challenge.update!(
      state: "verified", verified_at: verified_at, expires_at: @now + 20.days
    )

    assert Verification::Public.fresh_verification(
      **reference_attributes, workload: "standard", at: @now
    )
    assert Verification::Public.fresh_verification(
      **reference_attributes, workload: "high_volume", at: @now
    )
    assert_nil Verification::Public.fresh_verification(
      **reference_attributes, workload: "render", at: @now
    )
  end

  private

  def issue(method:)
    Verification::Public.issue_challenge(
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: @property.id,
      environment_id: @environment.id,
      method: method,
      clock: -> { @now }
    )
  end

  def attempt_attributes(challenge)
    {
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: @property.id,
      environment_id: @environment.id,
      challenge_id: challenge.id
    }
  end

  def revoke_attributes(challenge)
    attempt_attributes(challenge).merge(clock: -> { @now + 2.hours })
  end

  def reference_attributes
    {
      organization_id: @owner.organization.id,
      project_id: @project.id,
      property_id: @property.id,
      environment_id: @environment.id
    }
  end

  def fake_adapter(method, result)
    FakeAdapter.new(method: method, result: result, calls: [])
  end
end
