# frozen_string_literal: true

module Authorization
  class Permission < ApplicationRecord
    self.table_name = "permissions"

    SCOPES = %w[organization project].freeze
    RISK_LEVELS = %w[low medium high critical].freeze
    KEY_PATTERN = /\A[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+\z/
    CHECKSUM_PATTERN = /\A[0-9a-f]{64}\z/

    has_many :role_permissions, class_name: "Authorization::RolePermission", inverse_of: :permission,
      dependent: :restrict_with_exception
    has_many :roles, through: :role_permissions

    validates :key, presence: true, uniqueness: true, length: { maximum: 128 }, format: { with: KEY_PATTERN }
    validates :category, presence: true, length: { maximum: 64 }
    validates :scope, inclusion: { in: SCOPES }
    validates :risk_level, inclusion: { in: RISK_LEVELS }
    validates :description, presence: true, length: { maximum: 500 }
    validates :catalog_checksum, format: { with: CHECKSUM_PATTERN }
  end
end
