# frozen_string_literal: true

module Plans
  class CatalogSync
    def initialize(catalog: Catalog.load)
      @catalog = catalog
    end

    def call(dry_run: false)
      changes = dry_run ? planned_changes : apply_changes
      CatalogSyncResult.new(
        plan_count: @catalog.definitions.length,
        version_count: @catalog.definitions.length,
        changes: changes,
        dry_run: dry_run,
        checksum: @catalog.checksum
      )
    end

    private

    def planned_changes
      @catalog.definitions.flat_map do |definition|
        plan = Plan.find_by(key: definition.key)
        changes = []
        changes << "add plan #{definition.key}" unless plan
        changes << "reorder plan #{definition.key}" if plan && plan.display_order != definition.display_order
        version = plan && PlanVersion.find_by(plan_id: plan.id, version: definition.version)
        if version.nil?
          validate_version_sequence!(plan, definition)
          changes << "add #{definition.key} v#{definition.version}"
        elsif version_mismatch?(version, definition)
          raise PublishedVersionImmutable unless version.status == "draft"

          changes << "update #{definition.key} v#{definition.version}"
        end
        changes
      end.freeze
    end

    def apply_changes
      changes = []
      Plan.transaction do
        @catalog.definitions.each do |definition|
          plan = Plan.find_or_initialize_by(key: definition.key)
          if plan.new_record?
            plan.display_order = definition.display_order
            plan.save!
            changes << "add plan #{definition.key}"
          elsif plan.display_order != definition.display_order
            plan.update!(display_order: definition.display_order)
            changes << "reorder plan #{definition.key}"
          end
          synchronize_version(plan, definition, changes)
        end
        if changes.any?
          Auditing::Public.record!(
            action: "plan.catalog_synchronized",
            target_type: "PlanCatalog",
            result: "succeeded",
            metadata: { operation: "sync", change_count: changes.length }
          )
        end
      end
      changes.freeze
    end

    def synchronize_version(plan, definition, changes)
      version = PlanVersion.find_by(plan_id: plan.id, version: definition.version)
      attributes = definition.version_attributes(plan_id: plan.id)
      if version.nil?
        validate_version_sequence!(plan, definition)
        PlanVersion.create!(attributes.merge(status: "draft"))
        changes << "add #{definition.key} v#{definition.version}"
      elsif version_mismatch?(version, definition)
        raise PublishedVersionImmutable unless version.status == "draft"

        version.update!(attributes)
        changes << "update #{definition.key} v#{definition.version}"
      end
    end

    def version_mismatch?(version, definition)
      expected = definition.version_attributes(plan_id: version.plan_id).stringify_keys
      version.attributes.slice(*expected.keys) != expected
    end

    def validate_version_sequence!(plan, definition)
      previous = if plan
        PlanVersion.where(plan_id: plan.id).where.not(status: "draft").maximum(:version) || 0
      else
        0
      end
      return if definition.version == previous + 1

      raise CatalogVersionBumpInvalid
    end
  end
end
