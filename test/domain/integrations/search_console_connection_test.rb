# frozen_string_literal: true

require "test_helper"

class SearchConsoleConnectionTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "search-console-connection")
  end

  test "records separate least-scope consent without retaining its raw reference" do
    reference = SecureRandom.urlsafe_base64(48, false)
    grant = connection_grant(consent_reference: reference)

    assert_difference("Integrations::Connection.count", 1) do
      @connection = Integrations::Public.register_search_console_connection(
        actor_membership: @owner.membership,
        grant: grant
      )
    end
    record = Integrations::Connection.find(@connection.id)

    assert_equal "search_console_oauth", record.consent_kind
    assert_equal "search_console", record.provider
    assert_equal [ Integrations::SearchConsole::READONLY_SCOPE ], record.granted_scopes
    assert_equal Digest::SHA256.hexdigest(reference), record.consent_digest
    refute_includes record.attributes.to_json, reference
    assert_predicate @connection, :usable?
  end

  test "consent replay is idempotent and cannot cross tenant boundaries" do
    grant = connection_grant
    first = Integrations::Public.register_search_console_connection(
      actor_membership: @owner.membership, grant: grant
    )

    assert_no_difference("Integrations::Connection.count") do
      second = Integrations::Public.register_search_console_connection(
        actor_membership: @owner.membership, grant: grant
      )
      assert_equal first.id, second.id
    end

    foreign = create_organization_for(slug: "search-console-foreign")
    assert_raises(Integrations::AccessDenied) do
      Integrations::Public.register_search_console_connection(
        actor_membership: foreign.membership, grant: grant
      )
    end
  end

  test "rejects login-like or insufficient grants before persistence" do
    assert_raises(ArgumentError) do
      Integrations::SearchConsole::ConnectionGrant.new(
        external_account_id: "google-account-1",
        granted_scopes: [ "openid", "email" ],
        consented_at: Time.current,
        consent_reference: SecureRandom.urlsafe_base64(48, false),
        consent_kind: "google_login"
      )
    end
    assert_no_difference("Integrations::Connection.count") do
      assert_raises(Integrations::Invalid) do
        Integrations::Public.register_search_console_connection(
          actor_membership: @owner.membership,
          grant: Object.new
        )
      end
    end
  end

  private

  def connection_grant(consent_reference: SecureRandom.urlsafe_base64(48, false))
    Integrations::SearchConsole::ConnectionGrant.new(
      external_account_id: "google-account-1",
      granted_scopes: [ Integrations::SearchConsole::READONLY_SCOPE ],
      consented_at: Time.current,
      consent_reference: consent_reference
    )
  end
end
