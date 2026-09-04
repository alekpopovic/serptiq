# frozen_string_literal: true

module Billing
  class PlanChangesController < ApplicationController
    include Identity::LoginRequired
    include Tenancy::CurrentOrganization

    class_attribute :command_builder, instance_accessor: false,
      default: -> { BillingPlanChangeFactory.requester }

    layout "authenticated"
    before_action :establish_current_organization!
    before_action :redirect_alias_to_canonical_slug
    permission_required "billing.manage", only: :create

    def create
      result = Public.request_plan_change(
        command: self.class.command_builder.call,
        actor_membership: Current.membership,
        organization: Current.organization,
        target_plan_key: change_params.fetch(:target_plan_key),
        target_plan_version_id: change_params.fetch(:target_plan_version_id),
        currency: change_params.fetch(:currency),
        billing_interval: change_params.fetch(:billing_interval),
        request_key: "plan-change:#{request.request_id}",
        authorization: authorization_decision!("billing.manage")
      )
      redirect_to organization_plan_comparison_path(Current.organization.slug),
        notice: plan_change_notice(result)
    end

    private

    def change_params
      params.expect(plan_change: %i[target_plan_key target_plan_version_id currency billing_interval])
    end

    def plan_change_notice(result)
      result.effective_policy == "immediate" ?
        "Plan upgrade requested. Access changes after provider confirmation." :
        "Plan downgrade scheduled for the confirmed period end."
    end

    def redirect_alias_to_canonical_slug
      return if organization_slug_is_canonical?

      redirect_to organization_plan_comparison_path(Current.organization.slug), status: :see_other
    end
  end
end
