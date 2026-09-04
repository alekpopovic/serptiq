# frozen_string_literal: true

module Administration
  module Public
    module_function

    def plan_catalog_review(path: nil)
      BuildPlanCatalogReview.new.call(path: path)
    end

    def retire_plan_version(**attributes)
      RetirePlanVersion.new.call(**attributes)
    end

    def plan_catalog_consistency(path: nil, environment: Rails.env, at: Time.current)
      CheckPlanCatalogConsistency.new.call(path: path, environment: environment, at: at)
    end
  end
end
