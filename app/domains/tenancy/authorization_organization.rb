# frozen_string_literal: true

module Tenancy
  AuthorizationOrganization = Data.define(:id, :status) do
    def initialize(id:, status:)
      super(id: id.to_s.freeze, status: status.to_s.freeze)
      freeze
    end

    def active?
      status == "active"
    end
  end
end
