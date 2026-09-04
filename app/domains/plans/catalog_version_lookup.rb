# frozen_string_literal: true

module Plans
  class CatalogVersionLookup
    def call(plan_key:, version:, lock: false)
      relation = PlanVersion.joins(:plan).includes(:plan)
      relation = relation.lock if lock
      record = relation.find_by!(plans: { key: plan_key.to_s }, version: Integer(version))
      VersionSnapshot.from_record(record)
    rescue ActiveRecord::RecordNotFound, ArgumentError, TypeError
      raise CatalogTransitionInvalid.new(reason_code: "plan_version_not_found"), cause: nil
    end
  end
end
