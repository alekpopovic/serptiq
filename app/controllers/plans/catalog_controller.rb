# frozen_string_literal: true

module Plans
  class CatalogController < ApplicationController
    include Identity::LoginRequired

    layout "authenticated"
    authorization_exempt :index, :publish, :retire, reason: "platform_plan_catalog_permission"

    def index
      Public.authorize_catalog!(user: Current.user, permission: "plan_catalog.read")
      @publish_decision = Public.catalog_decision(user: Current.user, permission: "plan_catalog.publish")
      @entries = Public.catalog_entries
    end

    def publish
      authorization = publish_authorization!
      Public.publish_version(
        plan_key: params[:plan_key],
        version: params[:version],
        effective_at: nil,
        confirmation: params[:confirmation],
        authorization: authorization
      )
      redirect_to admin_plan_catalog_path, status: :see_other, notice: "Plan version published."
    end

    def retire
      authorization = publish_authorization!
      Public.retire_version(
        plan_key: params[:plan_key],
        version: params[:version],
        confirmation: params[:confirmation],
        authorization: authorization
      )
      redirect_to admin_plan_catalog_path, status: :see_other, notice: "Plan version retired."
    end

    private

    def publish_authorization!
      decision = Public.authorize_catalog!(user: Current.user, permission: "plan_catalog.publish")
      Identity::Public.verify_recent_session!(session: Current.session, user_id: Current.user.id)
      decision
    end
  end
end
