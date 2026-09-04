# frozen_string_literal: true

module Identity
  class SessionsController < ApplicationController
    include LoginRequired

    class_attribute :rate_limiter_factory,
      instance_accessor: false,
      default: -> { AuthenticationRateLimiter.from_settings }

    layout "authenticated", only: :index
    skip_before_action :require_authenticated_user, only: :destroy
    before_action :rate_limit_management_action, only: %i[revoke revoke_others]

    def index
      @sessions = Public.session_inventory(user: Current.user, current_session: Current.session)
    end

    def destroy
      Public.revoke_session(session: Current.session, reason: "logout") if Current.session
      identity_session_cookie.delete
      Current.reset

      redirect_to root_path, notice: "You have been signed out.", status: :see_other
    end

    def revoke
      Public.revoke_other_session!(session_id: params[:id], current_session: Current.session)
      redirect_to account_sessions_path, notice: "The selected session has been revoked.", status: :see_other
    end

    def revoke_others
      count = Public.revoke_all_other_sessions!(current_session: Current.session)
      message = count.zero? ? "There were no other active sessions." : "All other sessions have been revoked."
      redirect_to account_sessions_path, notice: message, status: :see_other
    end

    private

    def rate_limit_management_action
      self.class.rate_limiter_factory.call.consume!(
        scope: "session_action_session",
        key: Current.session.id
      )
    end
  end
end
