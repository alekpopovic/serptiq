# frozen_string_literal: true

module Authorization
  class ScopeRegistry
    def register(organization_id:, scope_type:, scope_id:, project_id: nil, status: "active", archived_at: nil)
      organization = Tenancy::Public.authorization_organization(organization_id: organization_id)
      raise AssignmentDenied.new(reason_code: "scope_mismatch") unless organization

      attributes = normalized_attributes(
        organization_id: organization.id, scope_type: scope_type, scope_id: scope_id,
        project_id: project_id, status: status, archived_at: archived_at
      )
      record = ScopeReference.find_or_initialize_by(id: attributes.fetch(:id))
      if record.persisted? && (record.organization_id != attributes.fetch(:organization_id) ||
          record.scope_type != attributes.fetch(:scope_type))
        raise AssignmentDenied.new(reason_code: "scope_mismatch")
      end
      record.assign_attributes(attributes)
      record.save!
      snapshot(record)
    rescue ActiveRecord::InvalidForeignKey, ActiveRecord::RecordInvalid
      raise AssignmentDenied.new(reason_code: "scope_mismatch"), cause: nil
    end

    def resolve(organization_id:, scope_type:, scope_id:, persist_organization: false)
      type = normalize_type(scope_type)
      record = if type == "Organization" && persist_organization
        ensure_organization(organization_id: organization_id, scope_id: scope_id)
      elsif type == "Organization" && scope_id.to_s == organization_id.to_s
        organization = Tenancy::Public.authorization_organization(organization_id: organization_id)
        if organization
          ScopeSnapshot.new(
            organization_id: organization.id, type: type, id: organization.id,
            project_id: nil, status: organization.status
          )
        end
      else
        ScopeReference.find_by(
          organization_id: organization_id, scope_type: type, id: scope_id
        )
      end
      record.is_a?(ScopeSnapshot) ? record : record && snapshot(record)
    end

    def resolve_chain(organization_id:, scope_type:, scope_id:, persist_organization: false)
      scope = resolve(
        organization_id: organization_id, scope_type: scope_type, scope_id: scope_id,
        persist_organization: persist_organization
      )
      return [] unless scope

      organization = resolve(
        organization_id: organization_id, scope_type: "Organization", scope_id: organization_id,
        persist_organization: persist_organization
      )
      return [] unless organization

      case scope.type
      when "Organization"
        [ organization ].freeze
      when "Project"
        [ organization, scope ].freeze
      when "Property"
        project = resolve(
          organization_id: organization_id, scope_type: "Project", scope_id: scope.project_id
        )
        project ? [ organization, project, scope ].freeze : [].freeze
      else
        [].freeze
      end
    end

    private

    def ensure_organization(organization_id:, scope_id:)
      raise AssignmentDenied.new(reason_code: "scope_mismatch") unless organization_id.to_s == scope_id.to_s

      organization = Tenancy::Public.authorization_organization(organization_id: organization_id)
      raise AssignmentDenied.new(reason_code: "scope_mismatch") unless organization

      status = organization.active? ? "active" : "archived"
      archived_at = organization.active? ? nil : Time.current
      ScopeReference.create_or_find_by!(id: organization.id) do |record|
        record.organization_id = organization.id
        record.scope_type = "Organization"
        record.status = status
        record.archived_at = archived_at
      end
    end

    def normalized_attributes(organization_id:, scope_type:, scope_id:, project_id:, status:, archived_at:)
      type = normalize_type(scope_type)
      state = status.to_s
      raise AssignmentDenied.new(reason_code: "resource_unavailable") unless ScopeReference::STATUSES.include?(state)

      {
        id: scope_id,
        organization_id: organization_id,
        scope_type: type,
        project_id: type == "Property" ? project_id : nil,
        project_scope_type: type == "Property" ? "Project" : nil,
        status: state,
        archived_at: state == "archived" ? (archived_at || Time.current) : nil
      }
    end

    def normalize_type(value)
      type = value.to_s.classify
      raise AssignmentDenied.new(reason_code: "scope_mismatch") unless ScopeReference::TYPES.include?(type)

      type
    end

    def snapshot(record)
      ScopeSnapshot.new(
        organization_id: record.organization_id, type: record.scope_type, id: record.id,
        project_id: record.project_id, status: record.status
      )
    end
  end
end
