# frozen_string_literal: true

class DashboardController < ApplicationController
  include Identity::LoginRequired

  class_attribute :first_run_status_resolver,
    instance_accessor: false,
    default: ->(user:) { Tenancy::Public.first_run_status(user: user) }

  layout "authenticated"

  before_action :route_first_run

  def index; end

  private

  def route_first_run
    status = self.class.first_run_status_resolver.call(user: Current.user)
    redirect_to onboarding_path, status: :see_other unless status.returning?
  end
end
