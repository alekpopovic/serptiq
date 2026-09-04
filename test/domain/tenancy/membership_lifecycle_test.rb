# frozen_string_literal: true

require "json"
require "test_helper"

class TenancyMembershipLifecycleTest < ActiveSupport::TestCase
  class CaptureLogger
    attr_reader :entries

    def initialize
      @entries = []
    end

    %i[debug info warn error fatal].each do |severity|
      define_method(severity) { |message| entries << [ severity, message ] }
    end
  end

  setup do
    @previous_emitter = Shared::Observability.emitter
    @logger = CaptureLogger.new
    Shared::Observability.emitter = Shared::Observability::EventEmitter.new(logger: @logger)
  end

  teardown { Shared::Observability.emitter = @previous_emitter }

  test "creates one active or invited membership with a safe attribution label" do
    owner = create_organization_for(slug: "membership-create")
    invited_user = create_identity_user(display_name: "  Invited Person  ")
    invited = Tenancy::Public.create_membership(
      actor_membership: owner.membership,
      user: invited_user,
      status: "invited"
    )

    assert invited.invited?
    assert_nil invited.accepted_at
    assert_equal "Invited Person", invited.display_name
    assert_raises(Tenancy::MembershipAlreadyExists) do
      Tenancy::Public.create_membership(
        actor_membership: owner.membership,
        user: invited_user,
        status: "active"
      )
    end

    removed = Tenancy::Public.change_membership_status(
      actor_membership: owner.membership,
      target_membership_id: invited.id,
      operation: "remove"
    )
    assert removed.removed?
    assert_nil removed.accepted_at
    assert_not_nil removed.removed_at
  end

  test "suspend reactivate and remove use explicit timestamps and revoke sessions" do
    now = Time.current.change(usec: 0)
    owner = create_organization_for(slug: "membership-transitions", at: now - 1.day)
    target_user = create_identity_user(display_name: "Historical Name")
    target = Tenancy::Public.create_membership(
      actor_membership: owner.membership,
      user: target_user,
      clock: -> { now - 1.hour }
    )
    session = issue_identity_session(user: target_user, at: now - 30.minutes)

    suspended = Tenancy::Public.change_membership_status(
      actor_membership: owner.membership,
      target_membership_id: target.id,
      operation: "suspend",
      clock: -> { now }
    )
    assert suspended.suspended?
    assert_equal now, suspended.suspended_at
    assert_equal "privilege_changed", session.session.reload.revoke_reason

    reactivated = Tenancy::Public.change_membership_status(
      actor_membership: owner.membership,
      target_membership_id: target.id,
      operation: "reactivate",
      clock: -> { now + 1.minute }
    )
    assert reactivated.active?
    assert_nil reactivated.suspended_at

    removed = Tenancy::Public.change_membership_status(
      actor_membership: owner.membership,
      target_membership_id: target.id,
      operation: "remove",
      clock: -> { now + 2.minutes }
    )
    assert removed.removed?
    assert_equal now + 2.minutes, removed.removed_at
    assert_equal now - 1.hour, removed.accepted_at
    target_user.update!(display_name: "Changed Identity Name")
    assert_equal "Historical Name", removed.reload.display_name
    assert_raises(Tenancy::InvalidMembershipTransition) do
      Tenancy::Public.change_membership_status(
        actor_membership: owner.membership,
        target_membership_id: target.id,
        operation: "reactivate"
      )
    end
  end

  test "current owner and cross-organization targets are protected" do
    owner = create_organization_for(slug: "owner-protection")
    foreign = create_organization_for(slug: "foreign-membership")

    error = assert_raises(Tenancy::LastOwnerConflict) do
      Tenancy::Public.change_membership_status(
        actor_membership: owner.membership,
        target_membership_id: owner.membership.id,
        operation: "suspend"
      )
    end
    assert_equal "last_owner_transfer_required", error.reason_code
    assert owner.membership.reload.active?

    assert_raises(Tenancy::OrganizationAccessDenied) do
      Tenancy::Public.change_membership_status(
        actor_membership: owner.membership,
        target_membership_id: foreign.membership.id,
        operation: "remove"
      )
    end
    assert foreign.membership.reload.active?
    assert_includes emitted_log, "membership.owner_invariant_blocked"
  end

  test "database constraints reject inconsistent state and unsafe display metadata" do
    result = create_organization_for(slug: "membership-constraints")

    assert_raises(ActiveRecord::StatementInvalid) do
      Tenancy::Membership.transaction(requires_new: true) do
        result.membership.update_columns(status: "suspended")
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Tenancy::Membership.transaction(requires_new: true) do
        quoted_id = Tenancy::Membership.connection.quote(result.membership.id)
        Tenancy::Membership.connection.execute(
          "UPDATE memberships SET display_name = '  padded  ' WHERE id = #{quoted_id}"
        )
      end
    end
  end

  test "transition audit carries hashed actor and subject without raw identifiers" do
    owner = create_organization_for(slug: "membership-audit")
    target = Tenancy::Public.create_membership(
      actor_membership: owner.membership,
      user: create_identity_user(display_name: "Audit Target")
    )
    Tenancy::Public.change_membership_status(
      actor_membership: owner.membership,
      target_membership_id: target.id,
      operation: "suspend"
    )

    record = @logger.entries.map(&:last).filter_map do |line|
      parsed = JSON.parse(line)
      parsed if parsed["event_name"] == "membership.suspended"
    end.sole
    assert_match(/\A[0-9a-f]{24}\z/, record.fetch("actor_id_hash"))
    assert_match(/\A[0-9a-f]{24}\z/, record.fetch("subject_id_hash"))
    refute_includes record.to_json, owner.membership.id
    refute_includes record.to_json, target.id
  end

  private

  def emitted_log
    @logger.entries.map(&:last).join("\n")
  end
end
