# frozen_string_literal: true

module Projects
  ProjectOperationalSnapshot = Data.define(
    :project_id, :health_state, :property_count, :latest_scan_state, :latest_scan_at
  ) do
    def initialize(project_id:, health_state: "not_observed", property_count: 0,
      latest_scan_state: "not_available", latest_scan_at: nil)
      super(
        project_id: project_id.to_s.freeze,
        health_state: health_state.to_s.freeze,
        property_count: Integer(property_count),
        latest_scan_state: latest_scan_state.to_s.freeze,
        latest_scan_at: latest_scan_at
      )
      freeze
    end
  end
end
