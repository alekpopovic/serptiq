# frozen_string_literal: true

module Authorization
  module ControllerPolicy
    extend ActiveSupport::Concern

    included do
      helper_method :allowed_to?
    end

    private

    def authorization_policy
      PolicyAdapter.new(actor_membership: Current.membership, organization: Current.organization)
    end

    def authorize_permission!(permission_key, **scope)
      authorization_policy.authorize!(permission_key: permission_key, **scope)
    end

    def allowed_to?(permission_key, **scope)
      authorization_policy.allowed?(permission_key: permission_key, **scope)
    end
  end
end
