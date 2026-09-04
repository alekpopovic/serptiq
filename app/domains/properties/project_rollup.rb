# frozen_string_literal: true

module Properties
  ProjectRollup = Data.define(
    :project_id, :health_state, :property_count, :latest_scan_state, :latest_scan_at
  ) do
    def initialize(project_id:, property_count:)
      super(
        project_id: project_id.to_s.freeze,
        health_state: "not_observed".freeze,
        property_count: Integer(property_count),
        latest_scan_state: "not_available".freeze,
        latest_scan_at: nil
      )
      freeze
    end
  end
end
