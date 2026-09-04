# frozen_string_literal: true

require "test_helper"

class InvitationAcceptanceConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    truncate_records
    @now = Time.current.change(usec: 0)
    owner_user = create_identity_user(display_name: "Concurrent Owner")
    @owner = create_organization_for(user: owner_user, slug: "concurrent-invitation")
    @target = create_identity_user(display_name: "Concurrent Target")
    create_verified_provider_identity(user: @target, email: "concurrent@example.test")
    @issued = Tenancy::IssueInvitation.new(
      clock: -> { @now },
      rate_limiter: permissive_limiter,
      delivery: ->(**) { }
    ).call(actor_membership: @owner.membership, email: "concurrent@example.test")
  end

  teardown { truncate_records }

  test "a token creates one membership under concurrent acceptance" do
    ready = Queue.new
    start = Queue.new
    outcomes = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          Tenancy::AcceptInvitation.new(
            clock: -> { @now }, rate_limiter: permissive_limiter
          ).call(token: @issued.token, user: @target, rate_limit_key: SecureRandom.hex(4))
          :accepted
        rescue Tenancy::InvitationAccessDenied
          :denied
        end
      end
    end
    2.times { ready.pop }
    2.times { start << true }

    assert_equal({ accepted: 1, denied: 1 }, outcomes.map(&:value).tally)
    assert_equal 1, Tenancy::Membership.where(
      organization_id: @owner.organization.id, user_id: @target.id
    ).count
    assert @issued.invitation.reload.accepted?
  end

  private

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

  def truncate_records
    ActiveRecord::Base.connection.execute(<<~SQL)
      TRUNCATE TABLE invitation_rate_limit_buckets, invitations, team_memberships, teams,
        organization_slug_aliases, organization_ownerships, memberships, organizations,
        sessions, oauth_transactions, identities, users RESTART IDENTITY CASCADE
    SQL
  end
end
