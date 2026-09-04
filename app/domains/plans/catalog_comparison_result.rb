# frozen_string_literal: true

module Plans
  CatalogComparisonResult = Data.define(:differences, :orphaned_draft_versions, :source_checksum) do
    def initialize(differences:, orphaned_draft_versions:, source_checksum:)
      super(
        differences: differences.freeze,
        orphaned_draft_versions: orphaned_draft_versions.freeze,
        source_checksum: source_checksum.to_s.freeze
      )
      freeze
    end
  end
end
