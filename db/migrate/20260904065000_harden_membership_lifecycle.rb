# frozen_string_literal: true

class HardenMembershipLifecycle < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :memberships, name: "memberships_lifecycle_consistency"
    remove_check_constraint :memberships, name: "memberships_status_allowlist"
    rename_column :memberships, :joined_at, :accepted_at
    rename_column :memberships, :left_at, :removed_at
    change_column_null :memberships, :accepted_at, true
    add_column :memberships, :display_name, :string, limit: 160

    execute <<~SQL.squish
      UPDATE memberships
      SET display_name = COALESCE(NULLIF(btrim(users.display_name), ''), 'Member')
      FROM users
      WHERE users.id = memberships.user_id
    SQL
    execute "UPDATE memberships SET status = 'removed' WHERE status = 'left'"
    change_column_null :memberships, :display_name, false

    add_index :memberships, %i[organization_id status created_at],
      name: "index_memberships_on_org_status_and_created"
    add_check_constraint :memberships,
      "status IN ('invited', 'active', 'suspended', 'removed')",
      name: "memberships_status_allowlist"
    add_check_constraint :memberships,
      membership_lifecycle_constraint,
      name: "memberships_lifecycle_consistency"
    add_check_constraint :memberships,
      "char_length(display_name) BETWEEN 1 AND 160 AND display_name = btrim(display_name)",
      name: "memberships_display_name_format"
  end

  def down
    remove_check_constraint :memberships, name: "memberships_display_name_format"
    remove_check_constraint :memberships, name: "memberships_lifecycle_consistency"
    remove_check_constraint :memberships, name: "memberships_status_allowlist"
    remove_index :memberships, name: "index_memberships_on_org_status_and_created"

    execute <<~SQL.squish
      UPDATE memberships
      SET accepted_at = COALESCE(accepted_at, created_at),
          removed_at = COALESCE(removed_at, created_at),
          status = 'left'
      WHERE status IN ('invited', 'removed')
    SQL
    change_column_null :memberships, :accepted_at, false
    rename_column :memberships, :accepted_at, :joined_at
    rename_column :memberships, :removed_at, :left_at
    remove_column :memberships, :display_name

    add_check_constraint :memberships,
      "status IN ('active', 'suspended', 'left')",
      name: "memberships_status_allowlist"
    add_check_constraint :memberships,
      old_membership_lifecycle_constraint,
      name: "memberships_lifecycle_consistency"
  end

  private

  def membership_lifecycle_constraint
    <<~SQL.squish
      (status = 'invited' AND accepted_at IS NULL AND suspended_at IS NULL AND removed_at IS NULL)
      OR (status = 'active' AND accepted_at IS NOT NULL AND suspended_at IS NULL AND removed_at IS NULL)
      OR (status = 'suspended' AND accepted_at IS NOT NULL AND suspended_at IS NOT NULL AND removed_at IS NULL)
      OR (status = 'removed' AND suspended_at IS NULL AND removed_at IS NOT NULL)
    SQL
  end

  def old_membership_lifecycle_constraint
    <<~SQL.squish
      (status = 'active' AND suspended_at IS NULL AND left_at IS NULL)
      OR (status = 'suspended' AND suspended_at IS NOT NULL AND left_at IS NULL)
      OR (status = 'left' AND left_at IS NOT NULL)
    SQL
  end
end
