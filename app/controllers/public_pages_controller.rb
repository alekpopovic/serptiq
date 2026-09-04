# frozen_string_literal: true

class PublicPagesController < ApplicationController
  include Identity::AnonymousOnly

  layout "public"

  anonymous_only only: %i[sign_in preview_sign_in]

  def home; end

  def sign_in
    @sign_in_form = Shell::SignInForm.new
    @return_to = Identity::SafeReturnPath.call(params[:return_to])
  end

  def preview_sign_in
    @sign_in_form = Shell::SignInForm.new(sign_in_params)
    @return_to = Identity::SafeReturnPath.call(params[:return_to])
    @sign_in_form.preview

    render :sign_in, status: :unprocessable_content
  end

  private

  def sign_in_params
    params.fetch(:shell_sign_in_form, ActionController::Parameters.new).permit(:provider)
  end
end
