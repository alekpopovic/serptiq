# frozen_string_literal: true

module Billing
  class PortalsController < ApplicationController
    include Identity::LoginRequired
    include Tenancy::CurrentOrganization
    include HostedRedirect

    class_attribute :command_builder, instance_accessor: false,
      default: -> { CreateCustomerPortal.from_settings(auditor: Auditing::Public) }

    layout "authenticated"
    before_action :establish_current_organization!
    before_action :redirect_alias_to_canonical_slug
    permission_required "billing.manage", only: :create

    def create
      link = Public.create_customer_portal(
        command: self.class.command_builder.call,
        actor_membership: Current.membership,
        organization: Current.organization,
        request_key: "portal-request:#{request.request_id}",
        authorization: authorization_decision!("billing.manage")
      )
      redirect_to_hosted_billing(link.url)
    end

    private

    def redirect_alias_to_canonical_slug
      return if organization_slug_is_canonical?

      redirect_to organization_plan_comparison_path(Current.organization.slug), status: :see_other
    end
  end
end
