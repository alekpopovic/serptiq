# frozen_string_literal: true

module Tenancy
  class OrganizationSlugAlias < ApplicationRecord
    self.table_name = "organization_slug_aliases"

    belongs_to :organization, class_name: "Tenancy::Organization", inverse_of: :slug_aliases

    normalizes :slug, with: ->(value) { OrganizationSlug.call(value) }

    validates :slug, presence: true, format: { with: Organization::SLUG_PATTERN },
      uniqueness: { case_sensitive: false }
    validate :slug_is_not_reserved
    validate :slug_is_not_current_elsewhere

    private

    def slug_is_not_reserved
      errors.add(:slug, "is reserved") if OrganizationSlugPolicy.reserved?(slug)
    end

    def slug_is_not_current_elsewhere
      return unless Organization.where(slug: slug).where.not(id: organization_id).exists?

      errors.add(:slug, "has already been taken")
    end
  end
end
