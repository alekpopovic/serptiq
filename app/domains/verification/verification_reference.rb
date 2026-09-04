# frozen_string_literal: true

module Verification
  VerificationReference = Data.define(
    :id, :organization_id, :project_id, :property_id, :environment_id,
    :method, :verified_at, :expires_at
  ) do
    def initialize(**attributes)
      %i[id organization_id project_id property_id environment_id method].each do |name|
        attributes[name] = attributes.fetch(name).to_s.freeze
      end
      super(**attributes)
      freeze
    end
  end
end
