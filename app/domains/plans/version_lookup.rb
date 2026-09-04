# frozen_string_literal: true

module Plans
  class VersionLookup
    def call(id:, lock: false)
      relation = PlanVersion.includes(:plan)
      relation = relation.lock if lock
      version = relation.find(id)
      VersionSnapshot.from_record(version)
    rescue ActiveRecord::RecordNotFound
      raise CatalogTransitionInvalid.new(reason_code: "plan_version_not_found"), cause: nil
    end
  end
end
