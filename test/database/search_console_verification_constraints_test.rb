# frozen_string_literal: true

require "test_helper"

class SearchConsoleVerificationConstraintsTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "search-console-constraints")
    @foreign = create_organization_for(slug: "search-console-constraints-foreign")
    @connection = create_connection(@owner)
  end

  test "database rejects a connection member from another tenant" do
    attributes = Integrations::Connection.find(@connection.id).attributes.except(
      "id", "created_at", "updated_at", "lock_version"
    ).merge(
      "id" => SecureRandom.uuid,
      "connected_by_membership_id" => @foreign.membership.id,
      "external_account_id" => "other-account",
      "consent_digest" => SecureRandom.hex(32),
      "created_at" => Time.current,
      "updated_at" => Time.current
    )

    assert_raises(ActiveRecord::StatementInvalid) do
      Integrations::Connection.transaction(requires_new: true) do
        Integrations::Connection.insert!(attributes)
      end
    end
  end

  test "database enforces separate consent lifecycle and bounded scopes" do
    record = Integrations::Connection.find(@connection.id)
    assert_raises(ActiveRecord::StatementInvalid) do
      Integrations::Connection.transaction(requires_new: true) do
        record.update_column(:consent_kind, "google_login")
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Integrations::Connection.transaction(requires_new: true) do
        record.update_columns(state: "revoked", revoked_at: nil)
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Integrations::Connection.transaction(requires_new: true) do
        record.update_column(:granted_scopes, { "token" => "secret" })
      end
    end
  end

  private

  def create_connection(result)
    Integrations::Public.register_search_console_connection(
      actor_membership: result.membership,
      grant: Integrations::SearchConsole::ConnectionGrant.new(
        external_account_id: "account-#{result.organization.slug}",
        granted_scopes: [ Integrations::SearchConsole::READONLY_SCOPE ],
        consented_at: Time.current,
        consent_reference: SecureRandom.urlsafe_base64(48, false)
      )
    )
  end
end
