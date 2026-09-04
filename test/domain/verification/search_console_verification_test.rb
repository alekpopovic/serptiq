# frozen_string_literal: true

require "test_helper"

class SearchConsoleVerificationTest < ActiveSupport::TestCase
  FakeClient = Struct.new(:properties, :error, :calls, keyword_init: true) do
    def list_properties(connection:)
      calls << connection.id
      raise error if error

      properties
    end
  end

  setup do
    Authorization::Public.sync_catalog
    @now = Time.zone.parse("2026-09-05 00:00:00 UTC")
    @owner = create_organization_for(slug: "search-console-verification")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "search-console-project")
    @property = create_property_for(
      @owner, project: @project, configuration: { origin: "https://example.com" }
    )
    @environment = @property.environments.sole
    @connection = register_connection(@owner)
    @access = property_access("https://example.com/", "siteOwner")
    @client = FakeClient.new(properties: [ @access ], calls: [])
  end

  test "lists only exact owner properties and persists only the selected observation" do
    unrelated = property_access("https://other.example.com/", "siteOwner")
    @client.properties = [ @access, unrelated ]
    catalog = catalog_for(@owner.membership)

    assert catalog.available?
    assert_equal [ "https://example.com/" ], catalog.options.map(&:external_property_identifier)
    issued = issue_from(catalog.options.sole.selection_token)
    challenge = issued.challenge

    assert_equal @connection.id, challenge.integration_connection_id
    assert_equal "https://example.com/", challenge.provider_property_identifier
    assert_equal "url_prefix", challenge.provider_property_type
    assert_equal "siteOwner", challenge.provider_permission_level
    assert_equal @now, challenge.provider_checked_at
    refute_includes challenge.attributes.to_json, unrelated.external_property_identifier
  end

  test "rechecks the exact selection and records provider permission and checked time" do
    issued = issue_from(catalog_for(@owner.membership).options.sole.selection_token)
    attempt_at = @now + 1.minute
    adapter = Verification::Adapters::SearchConsole.new(
      client: @client,
      resolver: Verification::SearchConsoleSelectionResolver.new(
        client: @client, clock: -> { attempt_at }
      )
    )
    registry = Verification::AdapterRegistry.new(adapters: { "search_console" => adapter })

    result = Verification::Public.attempt_challenge(
      **challenge_attributes(issued.challenge),
      registry: registry,
      clock: -> { attempt_at }
    )

    assert result.challenge.verified?
    assert_equal attempt_at, result.challenge.provider_checked_at
    assert_equal "siteOwner", result.challenge.provider_permission_level
    assert_equal true, result.challenge.evidence.fetch("provider_property_match")
    assert_equal 3, @client.calls.length
    assert_equal "verified", @property.reload.verification_status
  end

  test "permission and tenant checks precede selection or attempt consumption" do
    developer_user = create_identity_user(display_name: "Search Console Developer")
    developer = Tenancy::Public.create_membership(
      actor_membership: @owner.membership, user: developer_user
    )
    Authorization::Public.assign_role(
      actor_membership: @owner.membership,
      grantee_type: "Membership",
      grantee_id: developer.id,
      role_id: Authorization::Role.find_by!(system: true, key: "developer").id,
      scope_type: "Project",
      scope_id: @project.id
    )

    assert_raises(Verification::AccessDenied) { catalog_for(developer) }

    foreign = create_organization_for(slug: "search-console-selection-foreign")
    enable_project_limit(foreign)
    enable_property_limits(foreign)
    foreign_project = create_project_for(foreign, slug: "foreign-search-console")
    foreign_property = create_property_for(
      foreign, project: foreign_project, configuration: { origin: "https://example.com" }
    )
    foreign_connection = register_connection(foreign)
    foreign_client = FakeClient.new(properties: [ @access ], calls: [])
    foreign_catalog = Verification::Public.search_console_catalog(
      actor_membership: foreign.membership,
      project_id: foreign_project.id,
      property_id: foreign_property.id,
      environment_id: foreign_property.environments.sole.id,
      search_console_client: foreign_client
    )

    assert_no_difference("Verification::Challenge.count") do
      assert_raises(Verification::SearchConsoleSelectionError) do
        issue_from(foreign_catalog.options.sole.selection_token)
      end
    end
    assert_not_equal @connection.id, foreign_connection.id
  end

  test "classifies revoked scope outage inaccessible ambiguous no-match and insufficient permission" do
    resolver = Verification::SearchConsoleSelectionResolver.new(client: @client, clock: -> { @now })
    attributes = {
      organization_id: @owner.organization.id,
      connection_id: @connection.id,
      external_property_identifier: @access.external_property_identifier,
      origin: @environment.origin,
      expected_connection_revision: @connection.credential_revision
    }

    @client.properties = []
    assert_selection_failure("provider_property_inaccessible") { resolver.call(**attributes) }
    @client.properties = [ @access, @access ]
    assert_selection_failure("provider_ambiguous_match") { resolver.call(**attributes) }
    @client.properties = [ property_access("https://other.example.com/", "siteOwner") ]
    assert_selection_failure("provider_property_inaccessible") { resolver.call(**attributes) }
    assert_selection_failure("provider_no_match") do
      resolver.call(
        **attributes.merge(external_property_identifier: "https://other.example.com/")
      )
    end
    @client.properties = [ property_access("https://example.com/", "siteFullUser") ]
    error = assert_selection_failure("provider_insufficient_permission") { resolver.call(**attributes) }
    assert_equal "siteFullUser", error.observation.permission_level

    @client.error = Integrations::SearchConsole::ClientError.new("revoked_scope")
    assert_selection_failure("provider_scope_revoked") { resolver.call(**attributes) }
    @client.error = Integrations::SearchConsole::ClientError.new("outage")
    assert_selection_failure("provider_outage") { resolver.call(**attributes) }
  end

  test "adapter returns bounded revoked and insufficient-permission observations" do
    issued = issue_from(catalog_for(@owner.membership).options.sole.selection_token)
    expected_value = Verification::ChallengeToken.value_for(issued.challenge)
    adapter = Verification::Adapters::SearchConsole.new(client: @client)

    @client.properties = [ property_access("https://example.com/", "siteRestrictedUser") ]
    insufficient = adapter.verify(challenge: issued.challenge, expected_value: expected_value)
    assert_equal "provider_insufficient_permission", insufficient.failure_category
    assert_equal false, insufficient.evidence.fetch("provider_permission_owner")
    assert_equal "siteRestrictedUser", insufficient.provider_observation.permission_level

    @client.error = Integrations::SearchConsole::ClientError.new("revoked_scope")
    revoked = adapter.verify(challenge: issued.challenge, expected_value: expected_value)
    assert_equal "provider_scope_revoked", revoked.failure_category
    assert_nil revoked.provider_observation
    refute_includes revoked.evidence.to_json, @connection.external_account_id
  end

  test "connection authorization changes revoke current proof and reset the property" do
    issued = issue_from(catalog_for(@owner.membership).options.sole.selection_token)
    issued.challenge.update!(
      state: "verified", verified_at: @now, expires_at: @now + 30.days
    )
    @property.reload.update!(verification_status: "verified", verified_at: @now)

    connection = Integrations::Connection.find(@connection.id)
    connection.update!(credential_revision: connection.credential_revision + 1)

    assert issued.challenge.reload.revoked?
    assert_equal "unverified", @property.reload.verification_status
  end

  private

  def register_connection(result)
    Integrations::Public.register_search_console_connection(
      actor_membership: result.membership,
      grant: Integrations::SearchConsole::ConnectionGrant.new(
        external_account_id: "account-#{result.organization.slug}",
        granted_scopes: [ Integrations::SearchConsole::READONLY_SCOPE ],
        consented_at: @now,
        consent_reference: SecureRandom.urlsafe_base64(48, false)
      )
    )
  end

  def property_access(identifier, permission)
    Integrations::SearchConsole::PropertyAccess.new(
      external_property_identifier: identifier,
      permission_level: permission
    )
  end

  def catalog_for(membership)
    Verification::Public.search_console_catalog(
      actor_membership: membership,
      project_id: @project.id,
      property_id: @property.id,
      environment_id: @environment.id,
      search_console_client: @client
    )
  end

  def issue_from(selection_token)
    Verification::Public.issue_challenge(
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: @property.id,
      environment_id: @environment.id,
      method: "search_console",
      search_console_selection: selection_token,
      search_console_client: @client,
      clock: -> { @now }
    )
  end

  def challenge_attributes(challenge)
    {
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: @property.id,
      environment_id: @environment.id,
      challenge_id: challenge.id
    }
  end

  def assert_selection_failure(category)
    error = assert_raises(Verification::SearchConsoleSelectionError) { yield }
    assert_equal category, error.failure_category
    error
  end
end
