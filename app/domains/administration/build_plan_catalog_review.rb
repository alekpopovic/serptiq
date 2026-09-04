# frozen_string_literal: true

module Administration
  class BuildPlanCatalogReview
    def call(path: nil)
      comparison = path ? Plans::Public.compare_catalog(path: path) : Plans::Public.compare_catalog
      baseline_ids = comparison.differences.filter_map(&:baseline_version_id)
      counts = Billing::Public.active_subscriber_counts(plan_version_ids: baseline_ids)
      entries = comparison.differences.map do |difference|
        PlanCatalogReviewEntry.new(
          difference: difference,
          affected_subscriber_count: counts.fetch(difference.baseline_version_id.to_s, 0)
        )
      end
      PlanCatalogReview.new(
        entries: entries,
        orphaned_draft_versions: comparison.orphaned_draft_versions,
        source_checksum: comparison.source_checksum
      )
    end
  end
end
