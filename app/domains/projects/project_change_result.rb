# frozen_string_literal: true

module Projects
  ProjectChangeResult = Data.define(:project, :changed) do
    def initialize(project:, changed:)
      super(project: project, changed: !!changed)
      freeze
    end

    def changed?
      changed
    end
  end
end
