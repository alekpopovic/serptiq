# frozen_string_literal: true

module Identity
  class ProfilesController < ApplicationController
    include LoginRequired

    layout "authenticated"

    def show
      prepare_form
    end

    def update
      if Current.user.update(profile_params)
        redirect_to account_profile_path, notice: "Account preferences were updated.", status: :see_other
      else
        prepare_form
        render :show, status: :unprocessable_content
      end
    end

    private

    def profile_params
      params.expect(user: [ :display_name, :locale, :time_zone ])
    end

    def prepare_form
      @locales = [ [ "English", "en" ] ].freeze
      @time_zones = ActiveSupport::TimeZone.all.map(&:name).freeze
    end
  end
end
