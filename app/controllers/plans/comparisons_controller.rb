# frozen_string_literal: true

module Plans
  class ComparisonsController < ApplicationController
    include Identity::LoginRequired
    include Tenancy::CurrentOrganization

    class_attribute :checkout_availability_resolver,
      instance_accessor: false,
      default: ->(offer:, interval:) {
        Billing::Public.checkout_available?(
          plan_version_id: offer.id,
          currency: offer.currency,
          billing_interval: interval
        )
      }

    layout "authenticated"
    before_action :establish_current_organization!
    before_action :redirect_alias_to_canonical_slug
    permission_required "plans.read", only: :show
    permission_hint "billing.manage", only: :show

    def show
      @subscription = Billing::Public.active_subscription(organization_id: Current.organization.id)
      @offers = Public.current_offers(current_plan_version_id: @subscription&.plan_version_id)
      @current_offer = @offers.find(&:current?)
      @entitlement_definitions = Entitlements::Public.catalog_entries
      @checkout_availability = checkout_availability(@offers)
      @selected_offer = selected_offer(@offers)
      @selected_interval = selected_interval(@selected_offer)
      @active_checkout = Billing::Public.active_checkout?(organization_id: Current.organization.id)
      @portal_available = portal_available?
    end

    private

    def checkout_availability(offers)
      offers.to_h do |offer|
        intervals = offer.custom_pricing? ? [] : %w[monthly annual]
        [
          offer.id,
          intervals.to_h do |interval|
            [ interval, self.class.checkout_availability_resolver.call(offer: offer, interval: interval) ]
          end.freeze
        ]
      end.freeze
    end

    def selected_offer(offers)
      key = params[:target_plan_key].to_s
      return if key.blank?

      offers.find { |offer| offer.offered? && offer.plan_key == key }
    end

    def selected_interval(offer)
      interval = params[:billing_interval].to_s
      interval if offer && offer.billing_intervals.include?(interval)
    end

    def portal_available?
      provider = Rails.application.config.x.searchops.fetch(:billing_provider)
      provider != "disabled" && Billing::Public.portal_available?(
        organization_id: Current.organization.id,
        provider: provider
      )
    end

    def redirect_alias_to_canonical_slug
      return if organization_slug_is_canonical?

      redirect_to organization_plan_comparison_path(Current.organization.slug), status: :moved_permanently
    end
  end
end
