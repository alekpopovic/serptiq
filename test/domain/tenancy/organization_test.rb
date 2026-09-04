# frozen_string_literal: true

require "test_helper"

class TenancyOrganizationTest < ActiveSupport::TestCase
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

  test "creation normalizes a unique slug and creates active owner records atomically" do
    user = create_identity_user
    now = Time.current.change(usec: 0)

    result = Tenancy::CreateOrganization.new(clock: -> { now }).call(
      user: user,
      name: "  Example Workspace  ",
      slug: "  Éxample WORKSPACE  "
    )

    assert_match(/\A[0-9a-f-]{36}\z/, result.organization.id)
    assert_equal "Example Workspace", result.organization.name
    assert_equal "example-workspace", result.organization.slug
    assert result.organization.active?
    assert result.membership.active?
    assert_equal user.id, result.membership.user_id
    assert_equal now, result.membership.accepted_at
    assert_equal result.organization.id, result.ownership.organization_id
    assert_equal result.membership.id, result.ownership.membership_id
    assert_equal result.ownership.id, result.organization.current_ownership_id
    assert_equal now, result.ownership.assigned_at
    assert result.membership.owner?
    assert_includes emitted_log, "organization.created"

    duplicate = Tenancy::Organization.new(name: "Other", slug: "EXAMPLE-WORKSPACE")
    refute duplicate.valid?
    assert duplicate.errors.of_kind?(:slug, :taken)
  end

  test "owner assignment failure rolls the organization and membership back" do
    user = create_identity_user
    failure = ActiveRecord::RecordInvalid.new(Tenancy::OrganizationOwnership.new)
    failing_ownership_model = Class.new do
      define_singleton_method(:create!) { |**| raise failure }
    end

    counts = -> {
      [ Tenancy::Organization.count, Tenancy::Membership.count, Tenancy::OrganizationOwnership.count ]
    }
    assert_no_changes counts do
      assert_raises(ActiveRecord::RecordInvalid) do
        Tenancy::CreateOrganization.new(ownership_model: failing_ownership_model).call(
          user: user,
          name: "Rollback Org",
          slug: "rollback-org"
        )
      end
    end
  end

  test "database constraints reject invalid lifecycle and cross-organization ownership" do
    first = create_organization_for(slug: "first-org")
    second = create_organization_for(slug: "second-org")
    now = Time.current.change(usec: 0)

    assert_raises(ActiveRecord::StatementInvalid) do
      Tenancy::Organization.transaction(requires_new: true) do
        first.organization.update_columns(status: "deleted", deleted_at: now)
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      Tenancy::OrganizationOwnership.transaction(requires_new: true) do
        Tenancy::OrganizationOwnership.insert!({
          id: SecureRandom.uuid,
          organization_id: first.organization.id,
          membership_id: second.membership.id,
          assigned_at: now,
          ended_at: now,
          created_at: now,
          updated_at: now
        })
      end
    end
  end

  test "explicit lifecycle transitions preserve timestamp consistency and require the owner" do
    result = create_organization_for(slug: "lifecycle-org")
    outsider = Tenancy::Membership.create!(
      organization: result.organization,
      user_id: create_identity_user.id,
      status: "active",
      accepted_at: Time.current,
      display_name: "Lifecycle Member"
    )
    now = Time.current.change(usec: 0)

    suspended = Tenancy::Public.transition_organization(
      actor_membership: result.membership,
      to: "suspended",
      clock: -> { now }
    )
    assert_equal "suspended", suspended.status
    assert_equal now, suspended.suspended_at

    assert_raises(Tenancy::OrganizationAccessDenied) do
      Tenancy::Public.transition_organization(
        actor_membership: outsider,
        to: "active",
        clock: -> { now + 1.minute }
      )
    end
    assert_equal "suspended", result.organization.reload.status

    reactivated = Tenancy::Public.transition_organization(
      actor_membership: result.membership,
      to: "active",
      clock: -> { now + 1.minute }
    )
    assert reactivated.active?
    assert_nil reactivated.suspended_at
    assert_raises(Tenancy::InvalidOrganizationTransition) do
      Tenancy::Public.transition_organization(
        actor_membership: result.membership,
        to: "deleted",
        clock: -> { now + 2.minutes }
      )
    end
    assert_includes emitted_log, "organization.lifecycle_changed"
    assert_includes emitted_log, "organization.lifecycle_rejected"
  end

  test "only the owner can rename or change a slug and the event contains no customer value" do
    result = create_organization_for(name: "Original Name", slug: "original-name")
    member = Tenancy::Membership.create!(
      organization: result.organization,
      user_id: create_identity_user.id,
      status: "active",
      accepted_at: Time.current,
      display_name: "Settings Member"
    )

    updated = Tenancy::Public.update_organization(
      actor_membership: result.membership,
      name: "Renamed Workspace",
      slug: "renamed-workspace"
    )
    assert_equal "Renamed Workspace", updated.name
    assert_equal "renamed-workspace", updated.slug
    assert_includes emitted_log, "organization.renamed"
    refute_includes emitted_log, "Renamed Workspace"
    refute_includes emitted_log, "renamed-workspace"

    assert_raises(Tenancy::OrganizationAccessDenied) do
      Tenancy::Public.update_organization(
        actor_membership: member,
        name: "Attacker Rename",
        slug: "attacker-rename"
      )
    end
    assert_equal "Renamed Workspace", result.organization.reload.name
  end

  test "models use explicit relations and never a tenant default scope" do
    assert_empty Tenancy::Organization.default_scopes
    assert_empty Tenancy::Membership.default_scopes
    assert_empty Tenancy::OrganizationOwnership.default_scopes
  end

  private

  def emitted_log
    @logger.entries.map(&:last).join("\n")
  end
end
