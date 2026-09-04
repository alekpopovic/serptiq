# frozen_string_literal: true

class PublicPagesController < ApplicationController
  include Identity::AnonymousOnly

  layout "public"

  anonymous_only only: :sign_in

  def home; end

  def sign_in
    @return_to = Identity::SafeReturnPath.call(params[:return_to])
    @google_sign_in_enabled = Rails.application.config.x.searchops.fetch(:oauth_google_enabled)
    @github_sign_in_enabled = Rails.application.config.x.searchops.fetch(:oauth_github_enabled)
  end
end
