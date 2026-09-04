# frozen_string_literal: true

module Authorization
  class Role < ApplicationRecord
    self.table_name = "roles"

    SYSTEM_KEYS = %w[owner organization_admin billing_admin seo_lead developer content_editor analyst viewer].freeze
    SCOPES = %w[organization project].freeze
    KEY_PATTERN = /\A[a-z][a-z0-9_]{1,63}\z/

    has_many :role_permissions, class_name: "Authorization::RolePermission", inverse_of: :role,
      dependent: :restrict_with_exception
    has_many :permissions, through: :role_permissions

    validates :key, presence: true, length: { maximum: 64 }, format: { with: KEY_PATTERN }
    validates :name, presence: true, length: { maximum: 80 }
    validates :assignable_scopes, presence: true
    validate :ownership_is_consistent
    validate :assignable_scopes_are_valid
    validate :system_role_is_created_only_by_catalog
    before_destroy :prevent_system_role_destruction, prepend: true

    def readonly?
      persisted? && system?
    end

    private

    def prevent_system_role_destruction
      raise ActiveRecord::ReadOnlyRecord, "system roles are catalog managed" if system?
    end

    def ownership_is_consistent
      valid = if system?
        organization_id.nil? && !mutable? && archived_at.nil? && SYSTEM_KEYS.include?(key) && catalog_checksum.present?
      else
        organization_id.present? && mutable? && !SYSTEM_KEYS.include?(key) && catalog_checksum.nil?
      end
      errors.add(:system, "does not match role ownership") unless valid
    end

    def assignable_scopes_are_valid
      scopes = Array(assignable_scopes)
      errors.add(:assignable_scopes, "are invalid") unless scopes.present? && scopes.uniq == scopes &&
        (scopes - SCOPES).empty?
    end

    def system_role_is_created_only_by_catalog
      errors.add(:system, "roles are catalog managed") if new_record? && system?
    end
  end
end
