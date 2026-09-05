# frozen_string_literal: true

module Crawling
  ArtifactReference = Data.define(:organization_id, :project_id, :property_id, :artifact_id) do
    def initialize(**attributes)
      %i[organization_id project_id property_id artifact_id].each do |name|
        value = attributes.fetch(name).to_s
        raise ArgumentError, "artifact reference is invalid" unless Shared::Public.application_uuid?(value)

        attributes[name] = value.freeze
      end
      super(**attributes)
      freeze
    end
  end
end
