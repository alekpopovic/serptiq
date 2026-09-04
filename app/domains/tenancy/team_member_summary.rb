# frozen_string_literal: true

module Tenancy
  TeamMemberSummary = Data.define(:id, :display_name, :status, :effective) do
    def initialize(id:, display_name:, status:, effective:)
      super(id: id.to_s.freeze, display_name: display_name.to_s.freeze,
        status: status.to_s.freeze, effective: effective == true)
      freeze
    end

    def effective?
      effective
    end
  end
end
