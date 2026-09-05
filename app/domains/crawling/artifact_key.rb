# frozen_string_literal: true

module Crawling
  module ArtifactKey
    UUID_PATTERN = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
    KEY_PATTERN = %r{\Aorganizations/(#{UUID_PATTERN})/projects/(#{UUID_PATTERN})/properties/(#{UUID_PATTERN})/objects/([0-9a-f]{2})/(#{UUID_PATTERN})\z}
    PREFIX_PATTERN = %r{\Aorganizations/(#{UUID_PATTERN})/projects/(#{UUID_PATTERN})(?:/properties/(#{UUID_PATTERN}))?/\z}
    module_function

    def generate(organization_id:, project_id:, property_id:, uuid: SecureRandom.uuid)
      token = normalized_uuid!(uuid)
      "#{prefix(organization_id: organization_id, project_id: project_id, property_id: property_id)}" \
        "objects/#{token.delete('-').first(2)}/#{token}"
    end

    def prefix(organization_id:, project_id:, property_id:)
      organization = normalized_uuid!(organization_id)
      project = normalized_uuid!(project_id)
      property = normalized_uuid!(property_id)
      "organizations/#{organization}/projects/#{project}/properties/#{property}/"
    end

    def valid?(key)
      value = key.to_s
      match = KEY_PATTERN.match(value)
      value.bytesize.between?(32, 512) && value.valid_encoding? && match &&
        match.captures.values_at(0, 1, 2, 4).all? { |identifier| Shared::Public.application_uuid?(identifier) } &&
        match[4] == match[5].delete("-").first(2)
    end

    def valid_prefix?(prefix)
      value = prefix.to_s
      match = PREFIX_PATTERN.match(value)
      value.bytesize <= 400 && value.valid_encoding? && match &&
        match.captures.compact.all? { |identifier| Shared::Public.application_uuid?(identifier) }
    end

    def normalized_uuid!(value)
      normalized = value.to_s.downcase
      raise ArgumentError, "artifact scope identifier is invalid" unless Shared::Public.application_uuid?(normalized)

      normalized
    end
    private_class_method :normalized_uuid!
  end
end
