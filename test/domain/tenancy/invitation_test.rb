# frozen_string_literal: true

require "test_helper"

class TenancyInvitationTest < ActiveSupport::TestCase
  setup do
    @now = Time.current.change(usec: 0)
    @owner_user = create_identity_user(display_name: "Invitation Owner")
    @owner = create_organization_for(user: @owner_user, name: "Invite Workspace", slug: "invite-workspace")
    @target_user = create_identity_user(display_name: "Invited Person")
    create_verified_provider_identity(user: @target_user, email: "invited@example.test")
    @deliveries = []
  end

  test "issues a normalized one-time token without storing the raw value and accepts it once" do
    issued = issue(email: "  INVITED@example.test  ", initial_role_key: "analyst")

    assert_equal "invited@example.test", issued.invitation.email
    assert_equal "analyst", issued.invitation.initial_role_key
    assert_equal @owner.organization.id, issued.invitation.initial_scope_id
    assert_equal Tenancy::InvitationToken.digest(issued.token), issued.invitation.token_digest
    refute_includes issued.invitation.attributes.values.map(&:to_s), issued.token
    assert_equal issued.token, @deliveries.sole.token

    review = Tenancy::ReviewInvitation.new(clock: -> { @now }).call(token: issued.token, user: @target_user)
    assert_equal "Invite Workspace", review.organization_name

    membership = accept(issued.token)
    assert membership.active?
    assert_equal @owner.organization.id, membership.organization_id
    assert_equal "accepted", issued.invitation.reload.status

    assert_raises(Tenancy::InvitationAccessDenied) { accept(issued.token) }
    assert_equal 1, Tenancy::Membership.where(
      organization_id: @owner.organization.id, user_id: @target_user.id
    ).count
  end

  test "expired revoked and wrong verified email all deny acceptance" do
    expired = issue
    assert_raises(Tenancy::InvitationAccessDenied) do
      accept(expired.token, clock: -> { @now + 8.days })
    end
    assert_equal "expired", expired.invitation.reload.status

    revoked = issue(email: "revoked@example.test")
    Tenancy::ManageInvitation.new(clock: -> { @now }).revoke(
      actor_membership: @owner.membership,
      invitation_id: revoked.invitation.id
    )
    assert_raises(Tenancy::InvitationAccessDenied) { accept(revoked.token) }

    wrong = issue(email: "different@example.test")
    assert_raises(Tenancy::InvitationAccessDenied) { accept(wrong.token) }
  end

  test "suspended membership is explicitly reactivated while removed membership remains blocked" do
    suspended = Tenancy::Public.create_membership(actor_membership: @owner.membership, user: @target_user)
    Tenancy::Public.change_membership_status(
      actor_membership: @owner.membership, target_membership_id: suspended.id, operation: "suspend"
    )
    assert accept(issue.token).active?

    second_user = create_identity_user(display_name: "Removed Person")
    create_verified_provider_identity(user: second_user, email: "removed@example.test")
    removed = Tenancy::Public.create_membership(actor_membership: @owner.membership, user: second_user)
    Tenancy::Public.change_membership_status(
      actor_membership: @owner.membership, target_membership_id: removed.id, operation: "remove"
    )
    invitation = issue(email: "removed@example.test")
    assert_raises(Tenancy::RemovedMembershipReactivationDenied) do
      accept(invitation.token, user: second_user)
    end
    assert removed.reload.removed?
    assert invitation.invitation.reload.pending?
  end

  test "issuing again supersedes the old token and resend preserves bounded role intent" do
    first = issue(initial_role_key: "viewer")
    issuer = Tenancy::IssueInvitation.new(
      clock: -> { @now },
      rate_limiter: permissive_limiter,
      delivery: ->(issued:, inviter:) { @deliveries << issued }
    )
    second = Tenancy::ManageInvitation.new(clock: -> { @now }, issuer: issuer).resend(
      actor_membership: @owner.membership,
      invitation_id: first.invitation.id
    )

    assert first.invitation.reload.superseded?
    assert second.invitation.pending?
    assert_raises(Tenancy::InvitationAccessDenied) { accept(first.token) }
    assert_equal 2, @deliveries.length
  end

  test "first run exposes multiple matching organizations without exposing tokens" do
    issue
    other = create_organization_for(name: "Second Invitation", slug: "second-invitation")
    Tenancy::IssueInvitation.new(
      clock: -> { @now }, rate_limiter: permissive_limiter, delivery: ->(**) { }
    ).call(actor_membership: other.membership, email: "invited@example.test")

    summaries = Tenancy::Public.pending_invitation_summaries(user: @target_user)
    assert_equal [ "Invite Workspace", "Second Invitation" ], summaries.map(&:organization_name).sort
    assert Tenancy::Public.first_run_status(user: @target_user).invited?
    refute summaries.any? { |summary| summary.members.include?(:token) }
  end

  test "rate limits actor and destination through keyed counters" do
    limiter = Tenancy::InvitationRateLimiter.new(
      rules: {
        "issue_actor" => Tenancy::InvitationRateLimiter::Rule.new(1, 1.hour),
        "issue_destination" => Tenancy::InvitationRateLimiter::Rule.new(1, 1.hour)
      },
      clock: -> { @now }
    )
    issuer = Tenancy::IssueInvitation.new(clock: -> { @now }, rate_limiter: limiter, delivery: ->(**) { })
    issuer.call(actor_membership: @owner.membership, email: "limit-one@example.test")

    error = assert_raises(Tenancy::InvitationRateLimited) do
      issuer.call(actor_membership: @owner.membership, email: "limit-two@example.test")
    end
    assert_operator error.retry_after, :>, 0
    assert Tenancy::InvitationRateLimitBucket.all.all? { |bucket| bucket.key_digest.match?(/\A[0-9a-f]{64}\z/) }
    refute(Tenancy::InvitationRateLimitBucket.all.any? do |bucket|
      bucket.attributes.values.include?("limit-one@example.test")
    end)
  end

  test "model and database reject cross-organization initial access and acceptor tampering" do
    foreign = create_organization_for(slug: "invitation-foreign")
    invalid = Tenancy::Invitation.new(
      organization: @owner.organization,
      invited_by_membership: @owner.membership,
      email: "scope@example.test",
      token_digest: "a" * 64,
      expires_at: @now + 1.day,
      initial_role_key: "analyst",
      initial_scope_type: "Organization",
      initial_scope_id: foreign.organization.id
    )
    refute invalid.valid?
    assert_includes invalid.errors[:initial_role_key], "has an invalid organization scope"

    issued = issue
    assert_raises(ActiveRecord::StatementInvalid) do
      Tenancy::Invitation.transaction(requires_new: true) do
        issued.invitation.update_columns(
          status: "accepted",
          accepted_at: @now,
          accepted_by_membership_id: foreign.membership.id
        )
      end
    end
    assert issued.invitation.reload.pending?
  end

  private

  def issue(email: "invited@example.test", initial_role_key: nil)
    limiter = Tenancy::InvitationRateLimiter.new(
      rules: {
        "issue_actor" => Tenancy::InvitationRateLimiter::Rule.new(100, 1.hour),
        "issue_destination" => Tenancy::InvitationRateLimiter::Rule.new(100, 1.hour),
        "accept_ip" => Tenancy::InvitationRateLimiter::Rule.new(100, 1.hour)
      },
      clock: -> { @now }
    )
    Tenancy::IssueInvitation.new(
      clock: -> { @now }, rate_limiter: limiter, delivery: ->(issued:, inviter:) { @deliveries << issued }
    ).call(actor_membership: @owner.membership, email: email, initial_role_key: initial_role_key)
  end

  def accept(token, user: @target_user, clock: -> { @now })
    limiter = Tenancy::InvitationRateLimiter.new(
      rules: { "accept_ip" => Tenancy::InvitationRateLimiter::Rule.new(100, 1.hour) },
      clock: clock
    )
    Tenancy::AcceptInvitation.new(clock: clock, rate_limiter: limiter).call(
      token: token, user: user, rate_limit_key: "192.0.2.10"
    )
  end

  def permissive_limiter
    Tenancy::InvitationRateLimiter.new(
      rules: {
        "issue_actor" => Tenancy::InvitationRateLimiter::Rule.new(100, 1.hour),
        "issue_destination" => Tenancy::InvitationRateLimiter::Rule.new(100, 1.hour),
        "accept_ip" => Tenancy::InvitationRateLimiter::Rule.new(100, 1.hour)
      },
      clock: -> { @now }
    )
  end
end
