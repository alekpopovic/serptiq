# frozen_string_literal: true

class HardenProviderIdentityLifecycle < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  ACTIVE_PROVIDER_INDEX = "index_identities_on_active_user_and_provider"
  REVOCATION_CONSTRAINT = "identities_revocation_follows_creation"

  def up
    add_index :identities,
      [ :user_id, :provider ],
      unique: true,
      where: "revoked_at IS NULL",
      name: ACTIVE_PROVIDER_INDEX,
      algorithm: :concurrently
    add_check_constraint :identities,
      "revoked_at IS NULL OR revoked_at >= created_at",
      name: REVOCATION_CONSTRAINT,
      validate: false
    validate_check_constraint :identities, name: REVOCATION_CONSTRAINT
  end

  def down
    remove_check_constraint :identities, name: REVOCATION_CONSTRAINT
    remove_index :identities, name: ACTIVE_PROVIDER_INDEX, algorithm: :concurrently
  end
end
