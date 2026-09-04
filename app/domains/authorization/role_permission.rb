# frozen_string_literal: true

module Authorization
  class RolePermission < ApplicationRecord
    self.table_name = "role_permissions"

    belongs_to :role, class_name: "Authorization::Role", inverse_of: :role_permissions
    belongs_to :permission, class_name: "Authorization::Permission", inverse_of: :role_permissions

    validates :permission_id, uniqueness: { scope: :role_id }
    validate :system_grant_is_catalog_managed, on: :create

    def readonly?
      persisted? && role.system?
    end

    private

    def system_grant_is_catalog_managed
      errors.add(:role, "grants are catalog managed") if role&.system?
    end
  end
end
