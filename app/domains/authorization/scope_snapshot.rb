# frozen_string_literal: true

module Authorization
  ScopeSnapshot = Data.define(:organization_id, :type, :id, :project_id, :status) do
    def initialize(organization_id:, type:, id:, project_id:, status:)
      super(
        organization_id: organization_id.to_s.freeze,
        type: type.to_s.freeze,
        id: id.to_s.freeze,
        project_id: project_id&.to_s&.freeze,
        status: status.to_s.freeze
      )
      freeze
    end

    def active?
      status == "active"
    end
  end
end
