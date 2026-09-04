# frozen_string_literal: true

module TestSupport
  module TenancyHelpers
    def create_organization_for(user: create_identity_user, name: nil, slug: nil, at: Time.current)
      token = SecureRandom.hex(4)
      Tenancy::CreateOrganization.new(clock: -> { at }).call(
        user: user,
        name: name || "Organization #{token}",
        slug: slug || "organization-#{token}"
      )
    end
  end
end
