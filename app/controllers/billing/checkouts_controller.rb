# frozen_string_literal: true

module Billing
  class CheckoutsController < ApplicationController
    include Identity::LoginRequired
    include Tenancy::CurrentOrganization
    include HostedRedirect

    class_attribute :command_builder, instance_accessor: false,
      default: -> { CreateHostedCheckout.from_settings(auditor: Auditing::Public) }

    layout "authenticated"
    before_action :establish_current_organization!
    before_action :redirect_alias_to_canonical_slug
    permission_required "billing.manage", only: :create

    def create
      result = Public.create_hosted_checkout(
        command: self.class.command_builder.call,
        actor_membership: Current.membership,
        organization: Current.organization,
        plan_version_id: checkout_params.fetch(:plan_version_id),
        currency: checkout_params.fetch(:currency),
        billing_interval: checkout_params.fetch(:billing_interval),
        success_path: organization_billing_checkout_return_path(Current.organization.slug),
        cancel_path: organization_plan_comparison_path(Current.organization.slug),
        request_key: "checkout-request:#{request.request_id}",
        authorization: authorization_decision!("billing.manage")
      )
      redirect_to_hosted_billing(result.url)
    end

    private

    def checkout_params
      params.expect(checkout: %i[plan_version_id currency billing_interval])
    end

    def redirect_alias_to_canonical_slug
      return if organization_slug_is_canonical?

      redirect_to organization_plan_comparison_path(Current.organization.slug), status: :see_other
    end
  end
end
