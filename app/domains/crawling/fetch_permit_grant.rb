# frozen_string_literal: true

module Crawling
  FetchPermitGrant = Data.define(:id, :token, :host_key_digest, :expires_at) do
    def initialize(**attributes)
      %i[id token host_key_digest].each do |name|
        attributes[name] = attributes.fetch(name).to_s.freeze
      end
      valid = Shared::Public.application_uuid?(attributes[:id]) &&
        attributes[:token].bytesize == 64 && attributes[:host_key_digest].match?(/\A[0-9a-f]{64}\z/) &&
        attributes.fetch(:expires_at).respond_to?(:utc)
      raise ArgumentError, "fetch permit grant is invalid" unless valid

      super(**attributes)
      freeze
    end

    def inspect
      "#<#{self.class.name} id=#{id} expires_at=#{expires_at.utc.iso8601(6)}>"
    end
  end
end
