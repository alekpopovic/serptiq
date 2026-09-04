# frozen_string_literal: true

module Administration
  PlanCatalogReview = Data.define(:entries, :orphaned_draft_versions, :source_checksum) do
    def initialize(entries:, orphaned_draft_versions:, source_checksum:)
      super(
        entries: entries.freeze,
        orphaned_draft_versions: orphaned_draft_versions.freeze,
        source_checksum: source_checksum.to_s.freeze
      )
      freeze
    end

    def entry_for(plan_key:, version:)
      entries.find { |entry| entry.plan_key == plan_key.to_s && entry.source_version == version.to_i }
    end
  end
end
