# frozen_string_literal: true

module Crawling
  HttpFetchUsageContext = Data.define(:organization_id, :scan_id, :source_key_prefix) do
    def initialize(**attributes)
      organization_id = attributes.fetch(:organization_id).to_s
      scan_id = attributes.fetch(:scan_id).to_s
      prefix = attributes.fetch(:source_key_prefix).to_s
      valid = Shared::Public.application_uuid?(organization_id) &&
        Shared::Public.application_uuid?(scan_id) && prefix.bytesize.between?(8, 160) &&
        !prefix.include?("://") && !prefix.match?(/[[:cntrl:]]/)
      raise ArgumentError, "HTTP fetch usage context is invalid" unless valid

      super(
        organization_id: organization_id.freeze,
        scan_id: scan_id.freeze,
        source_key_prefix: prefix.freeze
      )
      freeze
    end

    def source_key(sequence)
      "#{source_key_prefix}:request:#{Integer(sequence)}"
    end
  end
end
