# frozen_string_literal: true

module Tenancy
  class InvitationEntriesController < ApplicationController
    before_action :set_sensitive_headers

    def show
      if InvitationToken.valid?(params[:token])
        invitation_cookie.write(token: params[:token])
      else
        invitation_cookie.delete
      end
      destination = Current.user ? invitation_review_path : sign_in_path(return_to: invitation_review_path)
      redirect_to destination, status: :see_other
    end

    private

    def invitation_cookie
      @invitation_cookie ||= InvitationCookie.new(cookies)
    end

    def set_sensitive_headers
      response.headers["Cache-Control"] = "no-store, max-age=0"
      response.headers["Pragma"] = "no-cache"
      response.headers["Referrer-Policy"] = "no-referrer"
      response.headers["X-Frame-Options"] = "DENY"
    end
  end
end
