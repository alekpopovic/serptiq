# frozen_string_literal: true

module Billing
  module HostedRedirect
    extend ActiveSupport::Concern

    private

    def redirect_to_hosted_billing(url)
      response.set_header("Cache-Control", "no-store")
      response.set_header("Pragma", "no-cache")
      response.set_header("Referrer-Policy", "no-referrer")
      redirect_to url, allow_other_host: true, status: :see_other
    end
  end
end
