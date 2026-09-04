# frozen_string_literal: true

module Billing
  class CheckoutReturnsController < ApplicationController
    include Identity::LoginRequired
    include Tenancy::CurrentOrganization

    layout "authenticated"
    before_action :establish_current_organization!
    before_action :redirect_alias_to_canonical_slug
    before_action :set_private_response_headers
    permission_required "plans.read", only: :show

    def show
      @subscription = Public.active_subscription(organization_id: Current.organization.id)
    end

    private

    def set_private_response_headers
      response.set_header("Cache-Control", "no-store")
      response.set_header("Referrer-Policy", "no-referrer")
    end

    def redirect_alias_to_canonical_slug
      return if organization_slug_is_canonical?

      redirect_to organization_billing_checkout_return_path(Current.organization.slug),
        status: :moved_permanently
    end
  end
end
