# frozen_string_literal: true

module Authorization
  class RoleAssignment < ApplicationRecord
    self.table_name = "role_assignments"

    GRANTEE_TYPES = %w[Membership Team].freeze
    SCOPE_TYPES = ScopeReference::TYPES
    EFFECTS = %w[allow].freeze

    belongs_to :role, class_name: "Authorization::Role", inverse_of: :role_assignments
    belongs_to :scope_reference, class_name: "Authorization::ScopeReference",
      foreign_key: :scope_id, inverse_of: :role_assignments

    validates :grantee_type, inclusion: { in: GRANTEE_TYPES }
    validates :scope_type, inclusion: { in: SCOPE_TYPES }
    validates :effect, inclusion: { in: EFFECTS }
    validates :grantee_id, uniqueness: {
      scope: %i[organization_id grantee_type role_id scope_type scope_id],
      conditions: -> { where(revoked_at: nil) }
    }, if: :active_record?
    validate :grantee_columns_are_consistent
    validate :role_is_usable_in_organization
    validate :scope_is_usable_in_organization
    validate :timestamps_are_consistent

    scope :unrevoked, -> { where(revoked_at: nil) }
    scope :effective_at, ->(time) { unrevoked.where("expires_at IS NULL OR expires_at > ?", time) }

    def active_at?(time = Time.current)
      revoked_at.nil? && (expires_at.nil? || expires_at > time)
    end

    private

    def active_record?
      revoked_at.nil?
    end

    def grantee_columns_are_consistent
      valid = if grantee_type == "Membership"
        membership_grantee_id == grantee_id && team_grantee_id.nil?
      elsif grantee_type == "Team"
        team_grantee_id == grantee_id && membership_grantee_id.nil?
      else
        false
      end
      errors.add(:grantee_id, "does not match grantee_type") unless valid
    end

    def role_is_usable_in_organization
      return unless role

      same_tenant = role.system? ? role_organization_id.nil? : role_organization_id == organization_id
      errors.add(:role_id, "must belong to the assignment organization") unless
        same_tenant && role_system == role.system? && role.archived_at.nil?
    end

    def scope_is_usable_in_organization
      return unless scope_reference

      errors.add(:scope_id, "must belong to the assignment organization") unless
        scope_reference.organization_id == organization_id && scope_reference.scope_type == scope_type
    end

    def timestamps_are_consistent
      errors.add(:expires_at, "must follow creation") if expires_at && created_at && expires_at <= created_at
      valid_revocation = revoked_at.nil? == revoked_by_membership_id.nil?
      errors.add(:revoked_at, "must include the revoking membership") unless valid_revocation
      errors.add(:revoked_at, "must follow creation") if revoked_at && created_at && revoked_at < created_at
    end
  end
end
