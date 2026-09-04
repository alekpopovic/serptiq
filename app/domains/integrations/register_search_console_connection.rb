# frozen_string_literal: true

require "digest"

module Integrations
  class RegisterSearchConsoleConnection
    def call(actor_membership:, grant:)
      raise Invalid unless grant.is_a?(SearchConsole::ConnectionGrant)

      organization_id = actor_membership&.organization_id
      Authorization::Public.authorize_access!(
        actor_membership: actor_membership,
        permission_key: "integrations.manage",
        organization: organization_id
      )
      digest = Digest::SHA256.hexdigest(grant.consent_reference)
      Connection.transaction do
        replay = Connection.lock.find_by(consent_digest: digest)
        if replay
          raise AccessDenied unless replay.organization_id == organization_id
          raise Invalid.new(reason_code: "integration_consent_replay_mismatch") unless
            replay.external_account_id == grant.external_account_id &&
              replay.granted_scopes.sort == grant.granted_scopes

          next replay.reference
        end

        connection = Connection.lock.find_by(
          organization_id: organization_id,
          provider: "search_console",
          external_account_id: grant.external_account_id,
          state: %w[connected healthy degraded reauthorization_required]
        )
        attributes = {
          connected_by_membership_id: actor_membership.id,
          consent_kind: grant.consent_kind,
          consent_digest: digest,
          granted_scopes: grant.granted_scopes,
          state: "connected",
          consented_at: grant.consented_at,
          revoked_at: nil
        }
        if connection
          connection.update!(**attributes, credential_revision: connection.credential_revision + 1)
        else
          connection = Connection.create!(
            **attributes,
            organization_id: organization_id,
            provider: "search_console",
            external_account_id: grant.external_account_id,
            credential_revision: 1
          )
        end
        connection.reference
      end
    rescue Shared::Public::AuthorizationError
      raise AccessDenied, cause: nil
    end
  end
end
