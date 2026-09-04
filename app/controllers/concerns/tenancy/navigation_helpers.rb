# frozen_string_literal: true

module Tenancy
  module NavigationHelpers
    extend ActiveSupport::Concern

    included do
      helper_method :organization_navigation_entries, :organization_switch_path_for
    end

    private

    def organization_navigation_entries
      @organization_navigation_entries ||= if Current.user
        Public.organization_navigation(user: Current.user)
      else
        [].freeze
      end
    end

    def organization_switch_path_for(entry)
      destination = controller_path == "tenancy/organization_settings" ? "settings" : "dashboard"
      switch_organization_path(organization_slug: entry.slug, destination: destination)
    end
  end
end
