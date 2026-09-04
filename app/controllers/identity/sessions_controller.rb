# frozen_string_literal: true

module Identity
  class SessionsController < ApplicationController
    def destroy
      Public.revoke_session(session: Current.session, reason: "logout") if Current.session
      identity_session_cookie.delete
      Current.reset

      redirect_to root_path, notice: "You have been signed out.", status: :see_other
    end
  end
end
