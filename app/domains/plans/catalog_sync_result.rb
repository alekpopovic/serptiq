# frozen_string_literal: true

module Plans
  CatalogSyncResult = Data.define(:plan_count, :version_count, :changes, :dry_run, :checksum) do
    def initialize(plan_count:, version_count:, changes:, dry_run:, checksum:)
      super(
        plan_count: plan_count,
        version_count: version_count,
        changes: changes.map(&:to_s).freeze,
        dry_run: !!dry_run,
        checksum: checksum.to_s.freeze
      )
      freeze
    end

    def change_count
      changes.length
    end

    def dry_run?
      dry_run
    end
  end
end
