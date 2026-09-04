# frozen_string_literal: true

require "json"
require "test_helper"

class TransferOwnershipTest < ActiveSupport::TestCase
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
    Authorization::Public.sync_catalog
    @now = Time.current.change(usec: 0)
    @owner_user = create_identity_user(display_name: "Previous Owner")
    @owner = create_organization_for(user: @owner_user, slug: "ownership-domain", at: @now - 1.day)
    @target_user = create_identity_user(display_name: "Next Owner")
    @target = Tenancy::Public.create_membership(
      actor_membership: @owner.membership,
      user: @target_user,
      clock: -> { @now - 1.hour }
    )
    @current_session = issue_identity_session(user: @owner_user, at: @now - 1.minute)
    @other_owner_session = issue_identity_session(user: @owner_user, at: @now - 2.minutes)
    @target_session = issue_identity_session(user: @target_user, at: @now - 2.minutes)
    @decision = transfer_decision
    @notifications = []
    @previous_emitter = Shared::Observability.emitter
    @logger = CaptureLogger.new
    Shared::Observability.emitter = Shared::Observability::EventEmitter.new(logger: @logger)
  end

  teardown { Shared::Observability.emitter = @previous_emitter }

  test "atomically moves explicit ownership rotates sessions and emits bounded security hooks" do
    subscriber = ->(*arguments) { @notifications << ActiveSupport::Notifications::Event.new(*arguments).payload }
    result = ActiveSupport::Notifications.subscribed(
      subscriber,
      Tenancy::OwnershipTransferNotifier::EVENT_NAME
    ) do
      transfer
    end

    assert_equal @target.id, result.current_ownership.membership_id
    assert_equal result.current_ownership.id, @owner.organization.reload.current_ownership_id
    assert_equal @now, result.previous_ownership.ended_at
    assert_nil result.current_ownership.ended_at
    refute_predicate @owner.membership.reload, :owner?
    assert_predicate @target.reload, :owner?
    assert_equal "privilege_changed", @current_session.session.reload.revoke_reason
    assert_equal "privilege_changed", @other_owner_session.session.reload.revoke_reason
    assert_equal "privilege_changed", @target_session.session.reload.revoke_reason
    assert_equal @current_session.session.id, result.issued_session.session.rotated_from_id
    assert_equal 1, result.revoked_current_owner_sessions
    assert_equal({
      organization_id: @owner.organization.id,
      previous_owner_user_id: @owner_user.id,
      current_owner_user_id: @target_user.id
    }, @notifications.sole)

    event = parsed_events.find { |row| row["event_name"] == "organization.ownership_transferred" }
    assert_equal "error", event.fetch("severity")
    assert_match(/\A[0-9a-f]{24}\z/, event.fetch("organization_id_hash"))
    assert_match(/\A[0-9a-f]{24}\z/, event.fetch("actor_id_hash"))
    assert_match(/\A[0-9a-f]{24}\z/, event.fetch("subject_id_hash"))
    refute_includes event.to_json, @owner.organization.id
    refute_includes event.to_json, @owner.membership.id
    refute_includes event.to_json, @target.id

    assert Authorization::Public.policy(
      actor_membership: @target,
      organization: @owner.organization
    ).allowed?(permission_key: "organization.transfer")
    refute Authorization::Public.policy(
      actor_membership: @owner.membership,
      organization: @owner.organization
    ).allowed?(permission_key: "organization.read")
  end

  test "rolls back every ownership and session change when a post-transition security hook fails" do
    identity = Object.new
    identity.define_singleton_method(:verify_recent_session!) do |**attributes|
      Identity::Public.verify_recent_session!(**attributes)
    end
    identity.define_singleton_method(:sessions_after_ownership_received!) do |**|
      raise "risk hook unavailable"
    end

    assert_raises(RuntimeError) { transfer(identity: identity) }

    assert_equal @owner.membership.id, @owner.organization.reload.current_ownership.membership_id
    assert_nil @owner.organization.current_ownership.ended_at
    assert_equal 1, Tenancy::OrganizationOwnership.where(
      organization_id: @owner.organization.id,
      ended_at: nil
    ).count
    assert_nil @current_session.session.reload.revoked_at
    assert_nil @target_session.session.reload.revoked_at
  end

  test "rejects stale sessions confirmation failures inactive and foreign targets" do
    @current_session.session.update!(authenticated_at: @now - 16.minutes)
    assert_raises(Identity::RecentAuthenticationRequired) { transfer }
    @current_session.session.update!(authenticated_at: @now - 1.minute)

    assert_raises(Tenancy::OwnershipTransferConfirmationInvalid) do
      transfer(confirmation: "transfer ownership")
    end

    Tenancy::Public.change_membership_status(
      actor_membership: @owner.membership,
      target_membership_id: @target.id,
      operation: "suspend"
    )
    error = assert_raises(Tenancy::OwnershipTransferDenied) { transfer }
    assert_equal "ownership_target_inactive", error.reason_code

    foreign = create_organization_for(slug: "foreign-ownership-domain")
    error = assert_raises(Tenancy::OwnershipTransferDenied) do
      transfer(target_membership_id: foreign.membership.id)
    end
    assert_equal "ownership_target_invalid", error.reason_code
    assert_equal @owner.membership.id, @owner.organization.reload.current_ownership.membership_id
  end

  private

  def transfer(target_membership_id: @target.id, confirmation: Tenancy::TransferOwnership::CONFIRMATION,
    identity: Identity::Public)
    Tenancy::TransferOwnership.new(clock: -> { @now }, identity: identity).call(
      actor_membership: @owner.membership,
      target_membership_id: target_membership_id,
      current_session: @current_session.session,
      session_metadata: Identity::SessionMetadata.empty,
      authorization: @decision,
      confirmation: confirmation
    )
  end

  def transfer_decision
    Authorization::Public.policy(
      actor_membership: @owner.membership,
      organization: @owner.organization
    ).decision(permission_key: "organization.transfer")
  end

  def parsed_events
    @logger.entries.filter_map do |_severity, message|
      JSON.parse(message)
    rescue JSON::ParserError
      nil
    end
  end
end
