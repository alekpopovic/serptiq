# frozen_string_literal: true

module Administration
  PlanCatalogReviewEntry = Data.define(:difference, :affected_subscriber_count) do
    def initialize(difference:, affected_subscriber_count:)
      super(difference: difference, affected_subscriber_count: Integer(affected_subscriber_count))
      freeze
    end

    delegate :plan_key, :source_version, :target_version_id, :baseline_version_id,
      :baseline_version, :kind, :additions, :changes, :removals, :database_drift,
      :source_checksum, :change_count, :expected_previous_version,
      :publication_confirmation, :publishable?, :version_bump_required?, to: :difference
  end
end
