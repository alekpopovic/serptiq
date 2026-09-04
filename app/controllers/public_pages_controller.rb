# frozen_string_literal: true

class PublicPagesController < ApplicationController
  layout "public"

  def home; end

  def sign_in
    @sign_in_form = Shell::SignInForm.new
  end

  def preview_sign_in
    @sign_in_form = Shell::SignInForm.new(sign_in_params)
    @sign_in_form.preview

    render :sign_in, status: :unprocessable_content
  end

  private

  def sign_in_params
    params.fetch(:shell_sign_in_form, ActionController::Parameters.new).permit(:provider)
  end
end
