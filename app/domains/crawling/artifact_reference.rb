# frozen_string_literal: true

module Crawling
  ArtifactReference = Data.define(:organization_id, :project_id, :property_id, :object_key) do
    def initialize(**attributes)
      %i[organization_id project_id property_id].each do |name|
        attributes[name] = attributes.fetch(name).to_s.freeze
      end
      key = attributes.fetch(:object_key).to_s
      expected_prefix = "organizations/#{attributes[:organization_id]}/projects/" \
        "#{attributes[:project_id]}/properties/#{attributes[:property_id]}/"
      valid_ids = %i[organization_id project_id property_id].all? do |name|
        Shared::Public.application_uuid?(attributes[name])
      end
      valid_key = key.valid_encoding? && key.bytesize.between?(expected_prefix.bytesize + 1, 1024) &&
        key.start_with?(expected_prefix) && !key.match?(/[\u0000\r\n]/)
      raise ArgumentError, "artifact reference is invalid" unless valid_ids && valid_key

      attributes[:object_key] = key.freeze
      super(**attributes)
      freeze
    end
  end
end
