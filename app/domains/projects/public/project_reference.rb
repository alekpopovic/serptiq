# frozen_string_literal: true

module Projects
  module Public
    ProjectReference = Data.define(:id, :organization_id, :status) do
      def initialize(id:, organization_id:, status:)
        super(
          id: id.to_s.freeze,
          organization_id: organization_id.to_s.freeze,
          status: status.to_s.freeze
        )
        freeze
      end

      def active?
        status == "active"
      end
    end
  end
end
