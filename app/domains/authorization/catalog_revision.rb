# frozen_string_literal: true

module Authorization
  class CatalogRevision < ApplicationRecord
    self.table_name = "authorization_catalog_revisions"

    validates :schema_version, :permission_count, :role_count,
      numericality: { only_integer: true, greater_than: 0 }
    validates :checksum, presence: true, uniqueness: true,
      format: { with: Permission::CHECKSUM_PATTERN }
    validates :source_path, inclusion: { in: [ "config_blueprints/permissions.yml" ] }
    validates :synced_at, presence: true

    def readonly?
      persisted?
    end
  end
end
