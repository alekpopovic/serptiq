# frozen_string_literal: true

module Plans
  class CatalogComparison
    SNAPSHOT_FIELDS = %w[
      display_name positioning currency pricing_kind monthly_price_cents annual_price_cents
    ].freeze

    def initialize(catalog: Catalog.load)
      @catalog = catalog
    end

    def call
      source_pairs = @catalog.definitions.map { |definition| [ definition.key, definition.version ] }
      CatalogComparisonResult.new(
        differences: @catalog.definitions.map { |definition| compare(definition) },
        orphaned_draft_versions: orphaned_drafts(source_pairs),
        source_checksum: @catalog.checksum
      )
    end

    private

    def compare(definition)
      plan = Plan.includes(:versions).find_by(key: definition.key)
      target = plan&.versions&.find { |version| version.version == definition.version }
      baseline = locked_baseline(plan)
      additions, changes, removals = differences(flatten(baseline), flatten(definition))
      drift = target ? all_changes(flatten(target), flatten(definition)) : []
      CatalogVersionDifference.new(
        plan_key: definition.key,
        source_version: definition.version,
        target_version_id: target&.id,
        baseline_version_id: baseline&.id,
        baseline_version: baseline&.version,
        kind: difference_kind(definition, target, baseline, additions, changes, removals, drift),
        additions: additions,
        changes: changes,
        removals: removals,
        database_drift: drift,
        source_checksum: definition.checksum
      )
    end

    def locked_baseline(plan)
      return unless plan

      plan.versions.reject { |version| version.status == "draft" }.max_by(&:version)
    end

    def difference_kind(definition, target, baseline, additions, changes, removals, drift)
      publication_changed = additions.any? || changes.any? || removals.any?
      return "initial_version" unless baseline
      if definition.version < baseline.version ||
          (definition.version == baseline.version && publication_changed)
        return "version_bump_required"
      end
      return "draft_out_of_sync" if target&.status == "draft" && drift.any?
      return "version_bump" if definition.version > baseline.version

      "unchanged"
    end

    def flatten(value)
      return {} unless value

      attributes = if value.is_a?(CatalogDefinition)
        SNAPSHOT_FIELDS.to_h { |field| [ field, value.public_send(field) ] }
          .merge("entitlements" => value.entitlements)
      else
        value.attributes.slice(*SNAPSHOT_FIELDS).merge("entitlements" => value.entitlements_snapshot)
      end
      entitlements = attributes.delete("entitlements") || attributes.delete(:entitlements) || {}
      attributes.stringify_keys.merge(
        entitlements.to_h.transform_keys { |key| "entitlements.#{key}" }
      )
    end

    def differences(before, after)
      additions = []
      changes = []
      removals = []
      (before.keys | after.keys).sort.each do |path|
        previous = before[path]
        current = after[path]
        next if previous == current

        change = CatalogValueChange.new(path: path, before: previous, after: current)
        if !before.key?(path)
          additions << change
        elsif !after.key?(path)
          removals << change
        else
          changes << change
        end
      end
      [ additions.freeze, changes.freeze, removals.freeze ]
    end

    def all_changes(before, after)
      additions, changes, removals = differences(before, after)
      (additions + changes + removals).freeze
    end

    def orphaned_drafts(source_pairs)
      PlanVersion.joins(:plan).where(status: "draft").filter_map do |version|
        pair = [ version.plan.key, version.version ]
        "#{pair.first} v#{pair.last}" unless source_pairs.include?(pair)
      end.sort.freeze
    end
  end
end
