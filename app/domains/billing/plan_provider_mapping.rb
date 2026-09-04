# frozen_string_literal: true

module Billing
  class PlanProviderMapping < ApplicationRecord
    self.table_name = "billing_plan_provider_mappings"

    ENVIRONMENTS = %w[development test staging production].freeze
    INTERVALS = %w[monthly annual].freeze
    PROVIDER_PATTERN = /\A[a-z][a-z0-9_]{1,31}\z/
    VARIANT_PATTERN = /\A[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}\z/

    validates :plan_version_id, :provider_variant_id, presence: true
    validates :provider, format: { with: PROVIDER_PATTERN }
    validates :provider_variant_id, format: { with: VARIANT_PATTERN }
    validates :environment, inclusion: { in: ENVIRONMENTS }
    validates :currency, format: { with: /\A[A-Z]{3}\z/ }
    validates :billing_interval, inclusion: { in: INTERVALS }
    validates :provider_variant_id, uniqueness: { scope: %i[provider environment] }
    validates :plan_version_id, uniqueness: {
      scope: %i[provider environment currency billing_interval],
      conditions: -> { where(active: true) },
      if: :active?
    }
  end
end
