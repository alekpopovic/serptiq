# frozen_string_literal: true

module Authorization
  CatalogSyncResult = Data.define(:checksum, :permission_count, :role_count, :grant_count, :change_count) do
    def initialize(checksum:, permission_count:, role_count:, grant_count:, change_count:)
      super
      freeze
    end
  end
end
