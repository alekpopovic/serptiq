# frozen_string_literal: true

class EnforceCurrentOwnershipIntegrity < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  MEMBERSHIP_IDENTITY_INDEX = "index_memberships_on_org_id_status"
  OWNERSHIP_IDENTITY_INDEX = "index_ownerships_on_org_id_current"
  OWNERSHIP_STATE_CHECK = "organization_ownerships_current_state"
  ORGANIZATION_CURRENT_CHECK = "organizations_current_ownership_active"
  ACTIVE_MEMBERSHIP_FK = "fk_current_ownership_active_membership"
  CURRENT_OWNERSHIP_FK = "fk_organizations_same_active_ownership"

  def up
    add_column :organization_ownerships, :current, :boolean unless
      column_exists?(:organization_ownerships, :current)
    add_column :organization_ownerships, :membership_status, :string, limit: 32 unless
      column_exists?(:organization_ownerships, :membership_status)
    execute <<~SQL.squish
      UPDATE organization_ownerships
      SET current = (ended_at IS NULL),
        membership_status = CASE WHEN ended_at IS NULL THEN 'active' ELSE NULL END
      WHERE current IS NULL
    SQL
    change_column_null :organization_ownerships, :current, false
    change_column_default :organization_ownerships, :current, from: nil, to: true
    change_column_default :organization_ownerships, :membership_status, from: nil, to: "active"

    add_column :organizations, :current_ownership_active, :boolean, null: false, default: true unless
      column_exists?(:organizations, :current_ownership_active)

    add_index :memberships, %i[organization_id id status], unique: true,
      name: MEMBERSHIP_IDENTITY_INDEX, algorithm: :concurrently unless
      index_exists?(:memberships, %i[organization_id id status], name: MEMBERSHIP_IDENTITY_INDEX)
    add_index :organization_ownerships, %i[organization_id id current], unique: true,
      name: OWNERSHIP_IDENTITY_INDEX, algorithm: :concurrently unless
      index_exists?(:organization_ownerships, %i[organization_id id current], name: OWNERSHIP_IDENTITY_INDEX)

    add_check_constraint :organization_ownerships, ownership_state_sql,
      name: OWNERSHIP_STATE_CHECK, validate: false unless
      check_constraint_exists?(:organization_ownerships, name: OWNERSHIP_STATE_CHECK)
    add_check_constraint :organizations, "current_ownership_active = true",
      name: ORGANIZATION_CURRENT_CHECK, validate: false unless
      check_constraint_exists?(:organizations, name: ORGANIZATION_CURRENT_CHECK)
    validate_check_constraint :organization_ownerships, name: OWNERSHIP_STATE_CHECK
    validate_check_constraint :organizations, name: ORGANIZATION_CURRENT_CHECK

    add_foreign_key :organization_ownerships, :memberships,
      column: %i[organization_id membership_id membership_status],
      primary_key: %i[organization_id id status],
      name: ACTIVE_MEMBERSHIP_FK,
      on_delete: :restrict,
      deferrable: :deferred,
      validate: false unless foreign_key_exists?(:organization_ownerships, name: ACTIVE_MEMBERSHIP_FK)
    add_foreign_key :organizations, :organization_ownerships,
      column: %i[id current_ownership_id current_ownership_active],
      primary_key: %i[organization_id id current],
      name: CURRENT_OWNERSHIP_FK,
      on_delete: :restrict,
      deferrable: :deferred,
      validate: false unless foreign_key_exists?(:organizations, name: CURRENT_OWNERSHIP_FK)
    validate_foreign_key :organization_ownerships, name: ACTIVE_MEMBERSHIP_FK
    validate_foreign_key :organizations, name: CURRENT_OWNERSHIP_FK
  end

  def down
    remove_foreign_key :organizations, name: CURRENT_OWNERSHIP_FK if
      foreign_key_exists?(:organizations, name: CURRENT_OWNERSHIP_FK)
    remove_foreign_key :organization_ownerships, name: ACTIVE_MEMBERSHIP_FK if
      foreign_key_exists?(:organization_ownerships, name: ACTIVE_MEMBERSHIP_FK)
    remove_check_constraint :organizations, name: ORGANIZATION_CURRENT_CHECK if
      check_constraint_exists?(:organizations, name: ORGANIZATION_CURRENT_CHECK)
    remove_check_constraint :organization_ownerships, name: OWNERSHIP_STATE_CHECK if
      check_constraint_exists?(:organization_ownerships, name: OWNERSHIP_STATE_CHECK)
    remove_index :organization_ownerships, name: OWNERSHIP_IDENTITY_INDEX, algorithm: :concurrently if
      index_exists?(:organization_ownerships, name: OWNERSHIP_IDENTITY_INDEX)
    remove_index :memberships, name: MEMBERSHIP_IDENTITY_INDEX, algorithm: :concurrently if
      index_exists?(:memberships, name: MEMBERSHIP_IDENTITY_INDEX)
    remove_column :organizations, :current_ownership_active if
      column_exists?(:organizations, :current_ownership_active)
    remove_column :organization_ownerships, :membership_status if
      column_exists?(:organization_ownerships, :membership_status)
    remove_column :organization_ownerships, :current if
      column_exists?(:organization_ownerships, :current)
  end

  private

  def ownership_state_sql
    <<~SQL.squish
      (current = true AND ended_at IS NULL AND membership_status = 'active') OR
      (current = false AND ended_at IS NOT NULL AND membership_status IS NULL)
    SQL
  end
end
