# frozen_string_literal: true

module Authorization
  class ScopeReference < ApplicationRecord
    self.table_name = "authorization_scope_references"

    TYPES = %w[Organization Project Property].freeze
    STATUSES = %w[active archived].freeze

    has_many :role_assignments, class_name: "Authorization::RoleAssignment", inverse_of: :scope_reference,
      dependent: :restrict_with_exception
    belongs_to :project_reference, class_name: "Authorization::ScopeReference",
      foreign_key: :project_id, optional: true, inverse_of: :property_references
    has_many :property_references, class_name: "Authorization::ScopeReference",
      foreign_key: :project_id, inverse_of: :project_reference, dependent: :restrict_with_exception

    validates :scope_type, inclusion: { in: TYPES }
    validates :status, inclusion: { in: STATUSES }
    validate :shape_is_consistent
    validate :project_is_same_organization

    def active?
      status == "active" && archived_at.nil?
    end

    def archived?
      status == "archived" && archived_at.present?
    end

    private

    def shape_is_consistent
      valid = case scope_type
      when "Organization"
        id == organization_id && project_id.nil? && project_scope_type.nil?
      when "Project"
        id != organization_id && project_id.nil? && project_scope_type.nil?
      when "Property"
        id != organization_id && project_id.present? && project_scope_type == "Project" && id != project_id
      else
        false
      end
      errors.add(:scope_type, "does not match the scope hierarchy") unless valid
      errors.add(:status, "does not match archived_at") unless active? || archived?
    end

    def project_is_same_organization
      return unless scope_type == "Property" && project_reference
      return if project_reference.scope_type == "Project" && project_reference.organization_id == organization_id

      errors.add(:project_id, "must reference a project in the same organization")
    end
  end
end
