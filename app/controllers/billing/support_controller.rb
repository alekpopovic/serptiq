# frozen_string_literal: true

module Billing
  class SupportController < ApplicationController
    include Identity::LoginRequired

    class_attribute :replayer_builder, instance_accessor: false,
      default: -> { BillingSupportFactory.replayer }
    class_attribute :reconciliation_builder, instance_accessor: false,
      default: -> { BillingSupportFactory.reconciliation_requester }

    layout "authenticated"
    authorization_exempt :index, :replay, :reconcile, reason: "platform_billing_support_permission"

    def index
      authorization = Public.authorize_support!(user: Current.user, permission: "billing_support.read")
      @dashboard = Public.support_dashboard(
        authorization: authorization,
        manage_decision: Public.support_decision(user: Current.user, permission: "billing_support.manage"),
        event_state: params[:state]
      )
    end

    def replay
      authorize_mutation!
      Public.replay_webhook_event(
        replayer: self.class.replayer_builder.call,
        webhook_event_id: params[:event_id],
        confirmation: params[:confirmation],
        actor_user_id: Current.user.id
      )
      redirect_to admin_billing_support_path, status: :see_other, notice: "Webhook replay queued."
    end

    def reconcile
      authorization = authorize_mutation!
      result = Public.request_reconciliation(
        command: self.class.reconciliation_builder.call,
        organization_id: params[:organization_id],
        subscription_id: params[:subscription_id],
        actor_user: Current.user,
        authorization: authorization
      )
      redirect_to admin_billing_support_path, status: :see_other,
        notice: "Targeted reconciliation #{result.state}."
    end

    private

    def authorize_mutation!
      decision = Public.authorize_support!(user: Current.user, permission: "billing_support.manage")
      Identity::Public.verify_recent_session!(session: Current.session, user_id: Current.user.id)
      decision
    end
  end
end
