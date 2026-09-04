# frozen_string_literal: true

module Usage
  class SourceReference < Data.define(:organization_id, :type, :id)
    TYPE_PATTERN = /\A[A-Z][A-Za-z0-9]{0,47}\z/

    def initialize(organization_id:, type:, id:)
      organization = organization_id.to_s
      source_type = type.to_s
      source_id = id.to_s
      raise Invalid.new(reason_code: "usage_source_invalid") unless
        Shared::Public.application_uuid?(organization) && Shared::Public.application_uuid?(source_id) &&
          TYPE_PATTERN.match?(source_type)

      super(organization_id: organization.freeze, type: source_type.freeze, id: source_id.freeze)
      freeze
    end
  end
end
