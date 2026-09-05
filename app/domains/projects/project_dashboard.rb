# frozen_string_literal: true

module Projects
  ProjectDashboard = Data.define(
    :project, :property_page, :property_readiness, :property_observation,
    :scan_observation, :findings_observation, :usage, :integration,
    :activity_page, :checklist, :scan_action, :generated_at
  ) do
    def initialize(**attributes)
      attributes[:checklist] = attributes.fetch(:checklist).freeze
      super(**attributes)
      freeze
    end
  end
end
