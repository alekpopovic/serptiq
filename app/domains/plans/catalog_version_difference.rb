# frozen_string_literal: true

module Plans
  CatalogVersionDifference = Data.define(
    :plan_key, :source_version, :target_version_id, :baseline_version_id,
    :baseline_version, :kind, :additions, :changes, :removals,
    :database_drift, :source_checksum
  ) do
    def initialize(**attributes)
      %i[additions changes removals database_drift].each do |key|
        attributes[key] = Array(attributes.fetch(key)).freeze
      end
      super(**attributes)
      freeze
    end

    def change_count
      additions.length + changes.length + removals.length
    end

    def expected_previous_version
      baseline_version || 0
    end

    def publication_confirmation
      "PUBLISH #{plan_key} VERSION #{source_version} AFTER #{expected_previous_version}"
    end

    def publishable?
      target_version_id.present? && database_drift.empty? &&
        %w[initial_version version_bump].include?(kind)
    end

    def version_bump_required?
      kind == "version_bump_required"
    end
  end
end
