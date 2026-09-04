# frozen_string_literal: true

module Administration
  class CheckPlanCatalogConsistency
    def call(path: nil, environment: Rails.env, at: Time.current)
      review = BuildPlanCatalogReview.new.call(path: path)
      issues = catalog_issues(review)
      mappings = Billing::Public.plan_provider_mappings(active: true)
      issues.concat(mapping_issues(mappings))
      issues.concat(missing_current_mapping_issues(review, mappings, environment.to_s, at))
      PlanCatalogConsistencyResult.new(issues: issues)
    end

    private

    def catalog_issues(review)
      issues = review.entries.flat_map do |entry|
        prefix = "#{entry.plan_key} v#{entry.source_version}"
        values = []
        values << "#{prefix}: database version is missing" unless entry.target_version_id
        values << "#{prefix}: database draft differs from YAML" if entry.database_drift.any?
        values << "#{prefix}: published changes require a version bump" if entry.version_bump_required?
        values
      end
      issues.concat(review.orphaned_draft_versions.map { |label| "#{label}: draft is absent from YAML" })
    end

    def mapping_issues(mappings)
      mappings.filter_map do |mapping|
        snapshot = Plans::Public.version_snapshot(id: mapping.plan_version_id)
        valid_interval = snapshot.pricing_kind == "fixed" &&
          %w[monthly annual].include?(mapping.billing_interval) &&
          snapshot.price_for(mapping.billing_interval).present?
        unless snapshot.currency == mapping.currency && valid_interval
          "provider mapping #{mapping.id}: currency or interval differs from plan snapshot"
        end
      rescue Shared::Public::ConflictError
        "provider mapping #{mapping.id}: plan version is unavailable"
      end
    end

    def missing_current_mapping_issues(review, mappings, environment, at)
      review.entries.flat_map do |entry|
        next [] unless entry.target_version_id

        snapshot = Plans::Public.purchasable_version(
          plan_key: entry.plan_key,
          currency: "EUR",
          billing_interval: "monthly",
          at: at
        )
        next [] unless snapshot.pricing_kind == "fixed"

        %w[monthly annual].filter_map do |interval|
          next unless snapshot.price_for(interval).positive?
          next if mappings.any? do |mapping|
            mapping.environment == environment && mapping.plan_version_id == snapshot.id &&
              mapping.currency == snapshot.currency && mapping.billing_interval == interval
          end

          "#{entry.plan_key} v#{snapshot.version}: missing #{environment} #{interval} provider mapping"
        end
      rescue Shared::Public::ConflictError
        []
      end
    end
  end
end
