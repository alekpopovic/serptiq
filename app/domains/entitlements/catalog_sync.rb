# frozen_string_literal: true

module Entitlements
  class CatalogSync
    def initialize(catalog: Catalog.load)
      @catalog = catalog
    end

    def call(dry_run: false)
      changes = dry_run ? planned_changes : apply_changes
      CatalogSyncResult.new(
        definition_count: @catalog.definitions.length,
        plan_value_count: @catalog.definitions.length * @catalog_plan_count,
        changes: changes,
        dry_run: dry_run,
        checksum: @catalog.checksum
      )
    end

    private

    def planned_changes
      @catalog_plan_count = 0
      changes = definition_changes
      plan_definitions.each do |plan|
        @catalog_plan_count += 1
        snapshot = Plans::Public.catalog_version(plan_key: plan.key, version: plan.version)
        changes.concat(plan_value_changes(plan, snapshot))
      rescue Shared::Public::ConflictError
        changes.concat(plan_value_changes(plan, nil))
      end
      changes.freeze
    end

    def apply_changes
      @catalog_plan_count = 0
      changes = []
      Entitlements.with_catalog_sync do
        Definition.transaction do
          definitions = synchronize_definitions(changes)
          plan_definitions.each do |plan|
            @catalog_plan_count += 1
            snapshot = Plans::Public.catalog_version(plan_key: plan.key, version: plan.version)
            synchronize_plan_values(plan, snapshot, definitions, changes)
          end
          audit_sync(changes) if changes.any?
        end
      end
      changes.freeze
    end

    def definition_changes
      @catalog.definitions.filter_map do |spec|
        record = Definition.find_by(key: spec.key)
        if record.nil?
          "add entitlement definition #{spec.key}"
        elsif definition_mismatch?(record, spec)
          raise CatalogConflict.new(reason_code: "entitlement_definition_revision_conflict")
        end
      end
    end

    def synchronize_definitions(changes)
      @catalog.definitions.to_h do |spec|
        record = Definition.find_by(key: spec.key)
        if record
          if definition_mismatch?(record, spec)
            raise CatalogConflict.new(reason_code: "entitlement_definition_revision_conflict")
          end
        else
          record = Definition.create!(spec.definition_attributes)
          changes << "add entitlement definition #{spec.key}"
        end
        [ spec.key, record ]
      end
    end

    def definition_mismatch?(record, spec)
      expected = serialized_definition_attributes(spec).stringify_keys
      record.attributes.slice(*expected.keys) != expected
    end

    def serialized_definition_attributes(spec)
      spec.definition_attributes.merge(
        minimum_value: spec.minimum_value && BigDecimal(spec.minimum_value.to_s),
        maximum_value: spec.maximum_value && BigDecimal(spec.maximum_value.to_s)
      )
    end

    def plan_definitions
      @catalog.plan_definitions
    end

    def plan_value_changes(plan, snapshot)
      expected_keys = @catalog.definitions.map(&:key)
      existing = if snapshot
        PlanValue.where(plan_version_id: snapshot.id).includes(:definition).index_by { |value| value.definition.key }
      else
        {}
      end
      extra = existing.keys - expected_keys
      raise CatalogConflict.new(reason_code: "plan_entitlement_catalog_extra") if extra.any?

      @catalog.definitions.filter_map do |definition|
        normalized = TypedValue.new.normalize(definition: definition, raw: plan.entitlements.fetch(definition.key))
        record = existing[definition.key]
        if record.nil?
          "add #{plan.key} v#{plan.version} entitlement #{definition.key}"
        elsif plan_value_mismatch?(record, definition, normalized, plan.checksum)
          raise CatalogConflict.new(reason_code: "published_plan_entitlement_immutable") unless snapshot&.status == "draft"
          "update #{plan.key} v#{plan.version} entitlement #{definition.key}"
        end
      end
    end

    def synchronize_plan_values(plan, snapshot, definitions, changes)
      expected_keys = @catalog.definitions.map(&:key)
      existing = PlanValue.where(plan_version_id: snapshot.id).includes(:definition).index_by { |value| value.definition.key }
      raise CatalogConflict.new(reason_code: "plan_entitlement_catalog_extra") if (existing.keys - expected_keys).any?

      @catalog.definitions.each do |definition|
        normalized = TypedValue.new.normalize(definition: definition, raw: plan.entitlements.fetch(definition.key))
        attributes = plan_value_attributes(snapshot, definitions.fetch(definition.key), definition, normalized, plan)
        record = existing[definition.key]
        if record.nil?
          PlanValue.create!(attributes)
          changes << "add #{plan.key} v#{plan.version} entitlement #{definition.key}"
        elsif plan_value_mismatch?(record, definition, normalized, plan.checksum)
          raise CatalogConflict.new(reason_code: "published_plan_entitlement_immutable") unless snapshot.status == "draft"
          record.update!(attributes.except(:plan_version_id, :entitlement_definition_id))
          changes << "update #{plan.key} v#{plan.version} entitlement #{definition.key}"
        end
      end
    end

    def plan_value_attributes(snapshot, record_definition, definition, normalized, plan)
      {
        plan_version_id: snapshot.id,
        entitlement_definition_id: record_definition.id,
        value_type: definition.value_type,
        value_state: normalized.state,
        value: normalized.stored_value,
        catalog_checksum: plan.checksum
      }
    end

    def plan_value_mismatch?(record, definition, normalized, checksum)
      record.value_type != definition.value_type || record.value_state != normalized.state ||
        record.value != normalized.stored_value || record.catalog_checksum != checksum
    end

    def audit_sync(changes)
      Auditing::Public.record!(
        action: "entitlement.catalog_synchronized",
        target_type: "EntitlementCatalog",
        result: "succeeded",
        metadata: { operation: "sync", change_count: changes.length }
      )
    end
  end
end
