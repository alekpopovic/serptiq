# frozen_string_literal: true

require "test_helper"

class DomainVerificationConstraintsTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "verification-constraints")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "verification-constraints-project")
    @property = create_property_for(@owner, project: @project)
    @environment = @property.environments.sole
    @challenge = Verification::Public.issue_challenge(
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: @property.id,
      environment_id: @environment.id,
      method: "dns_txt"
    ).challenge
  end

  test "database rejects cross tenant issuer and environment substitutions" do
    foreign = create_organization_for(slug: "verification-constraint-foreign")

    assert_raises(ActiveRecord::StatementInvalid) do
      Verification::Challenge.transaction(requires_new: true) do
        duplicate_challenge(issued_by_membership_id: foreign.membership.id)
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Verification::Challenge.transaction(requires_new: true) do
        duplicate_challenge(environment_id: SecureRandom.uuid)
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Verification::Challenge.transaction(requires_new: true) do
        duplicate_challenge(bound_origin: "https://stale.example.com")
      end
    end
  end

  test "database protects immutable challenge binding and append only attempts" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Verification::Challenge.transaction(requires_new: true) do
        @challenge.update_column(:bound_origin, "https://attacker.example.com")
      end
    end

    attempt = Verification::Attempt.create!(
      organization_id: @challenge.organization_id,
      project_id: @challenge.project_id,
      property_id: @challenge.property_id,
      environment_id: @challenge.environment_id,
      domain_verification_id: @challenge.id,
      sequence: 1,
      outcome: "failed",
      failure_category: "proof_missing",
      evidence: { "record_count" => 0 },
      attempted_at: Time.current,
      created_at: Time.current
    )
    assert_raises(ActiveRecord::StatementInvalid) do
      Verification::Attempt.transaction(requires_new: true) do
        attempt.update_column(:outcome, "verified")
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Verification::Attempt.transaction(requires_new: true) { attempt.delete }
    end
  end

  test "database origin trigger revokes current proof even when callbacks are bypassed" do
    @environment.update_columns(
      host: "changed.example.com",
      origin: "https://changed.example.com",
      updated_at: Time.current
    )

    assert @challenge.reload.revoked?
    assert_equal "unverified", @property.reload.verification_status
  end

  test "database allows normalized DNS categories and rejects arbitrary failure labels" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Verification::Challenge.transaction(requires_new: true) do
        duplicate_challenge(failure_category: "resolver said token=secret")
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Verification::Attempt.transaction(requires_new: true) do
        Verification::Attempt.insert!({
          id: SecureRandom.uuid,
          organization_id: @challenge.organization_id,
          project_id: @challenge.project_id,
          property_id: @challenge.property_id,
          environment_id: @challenge.environment_id,
          domain_verification_id: @challenge.id,
          sequence: 1,
          outcome: "failed",
          failure_category: "raw timeout from resolver.example",
          evidence: {},
          attempted_at: Time.current,
          created_at: Time.current
        })
      end
    end
  end

  private

  def duplicate_challenge(overrides)
    attributes = @challenge.attributes.except(
      "id", "created_at", "updated_at", "lock_version"
    ).merge(
      "challenge_digest" => SecureRandom.hex(32),
      "expected_location" => "_searchops-verification.other.example.com",
      "bound_origin" => @challenge.bound_origin,
      "state" => "failed",
      "attempt_count" => 1,
      "attempted_at" => Time.current,
      "failed_at" => Time.current,
      "failure_category" => "proof_missing",
      "created_at" => Time.current,
      "updated_at" => Time.current
    ).merge(overrides.stringify_keys)
    Verification::Challenge.insert!(attributes)
  end
end
