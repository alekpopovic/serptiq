# frozen_string_literal: true

class DashboardController < ApplicationController
  include Identity::LoginRequired

  layout "authenticated"

  def index; end
end
