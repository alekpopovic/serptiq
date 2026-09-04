# frozen_string_literal: true

module Usage
  class CatalogSync
    def initialize(catalog: Catalog.load)
      @catalog = catalog
    end

    def call(dry_run: false)
      changes = dry_run ? planned_changes : apply_changes
      CatalogSyncResult.new(
        meter_count: @catalog.meters.length,
        rate_count: @catalog.meters.sum { |meter| meter.rates.length },
        changes: changes,
        dry_run: dry_run,
        checksum: @catalog.checksum
      )
    end

    private

    def planned_changes
      @catalog.meters.flat_map do |spec|
        definition = MeterDefinition.find_by(key: spec.key)
        verify_definition!(definition, spec) if definition
        changes = definition ? [] : [ "add usage meter #{spec.key}" ]
        changes.concat(rate_changes(definition, spec))
      end.freeze
    end

    def apply_changes
      changes = []
      MeterDefinition.transaction do
        @catalog.meters.each do |spec|
          definition = MeterDefinition.find_by(key: spec.key)
          if definition
            verify_definition!(definition, spec)
          else
            definition = MeterDefinition.create!(spec.definition_attributes)
            changes << "add usage meter #{spec.key}"
          end
          synchronize_rates(definition, spec, changes)
        end
        audit_sync(changes) if changes.any?
      end
      changes.freeze
    end

    def rate_changes(definition, spec)
      spec.rates.filter_map do |rate|
        record = definition && MeterRate.find_by(
          usage_meter_definition_id: definition.id, version: rate.version
        )
        if record
          verify_rate!(record, rate)
          nil
        else
          "add usage meter #{spec.key} rate v#{rate.version}"
        end
      end
    end

    def synchronize_rates(definition, spec, changes)
      spec.rates.each do |rate|
        record = MeterRate.find_by(usage_meter_definition_id: definition.id, version: rate.version)
        if record
          verify_rate!(record, rate)
        else
          MeterRate.create!(rate.attributes_for(meter_definition_id: definition.id))
          changes << "add usage meter #{spec.key} rate v#{rate.version}"
        end
      end
    end

    def verify_definition!(record, spec)
      expected = spec.definition_attributes.stringify_keys
      return if record.attributes.slice(*expected.keys) == expected

      raise Conflict.new(reason_code: "usage_meter_definition_conflict")
    end

    def verify_rate!(record, spec)
      expected = spec.attributes_for(meter_definition_id: record.usage_meter_definition_id)
      actual = record.attributes.slice(*expected.stringify_keys.keys)
      normalized = expected.merge(weight: BigDecimal(spec.weight.to_s), effective_at: spec.effective_at).stringify_keys
      return if actual == normalized

      raise Conflict.new(reason_code: "usage_meter_rate_conflict")
    end

    def audit_sync(changes)
      Auditing::Public.record!(
        action: "usage.catalog_synchronized",
        target_type: "UsageCatalog",
        result: "succeeded",
        metadata: { operation: "sync", change_count: changes.length }
      )
    end
  end
end
