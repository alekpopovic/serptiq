# frozen_string_literal: true

module Administration
  PlanCatalogConsistencyResult = Data.define(:issues) do
    def initialize(issues:)
      super(issues: issues.map { |issue| issue.to_s.freeze }.uniq.sort.freeze)
      freeze
    end

    def consistent?
      issues.empty?
    end
  end
end
