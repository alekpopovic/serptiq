# frozen_string_literal: true

class OnboardingController < ApplicationController
  include Identity::LoginRequired

  class_attribute :first_run_status_resolver,
    instance_accessor: false,
    default: ->(user:) { Tenancy::Public.first_run_status(user: user) }

  layout "authenticated"

  def show
    @first_run_status = self.class.first_run_status_resolver.call(user: Current.user)
    @pending_invitations = Tenancy::Public.pending_invitation_summaries(user: Current.user)
    redirect_to dashboard_path, status: :see_other if @first_run_status.returning?
  end
end
