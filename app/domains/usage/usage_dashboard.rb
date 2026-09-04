# frozen_string_literal: true

module Usage
  UsageDashboard = Data.define(:organization_id, :entries, :generated_at) do
    def initialize(organization_id:, entries:, generated_at:)
      super(
        organization_id: organization_id.to_s.freeze,
        entries: entries.freeze,
        generated_at: generated_at
      )
      freeze
    end

    def quota_exhausted?
      entries.any?(&:exhausted?)
    end
  end
end
