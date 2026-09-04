# frozen_string_literal: true

class PublicPagesController < ApplicationController
  include Identity::AnonymousOnly

  class_attribute :provider_availability_resolver,
    instance_accessor: false,
    default: -> {
      settings = Rails.application.config.x.searchops
      {
        google: settings.fetch(:oauth_google_enabled),
        github: settings.fetch(:oauth_github_enabled)
      }.freeze
    }

  layout "public"

  anonymous_only only: :sign_in

  def home; end

  def pricing
    @offers = Plans::Public.current_offers
    @entitlement_definitions = Entitlements::Public.catalog_entries
  end

  def sign_in
    @return_to = Identity::SafeReturnPath.call(params[:return_to])
    availability = self.class.provider_availability_resolver.call
    @google_sign_in_enabled = availability.fetch(:google)
    @github_sign_in_enabled = availability.fetch(:github)
  end
end
