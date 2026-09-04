# frozen_string_literal: true

module Billing
  class PlanChangeConflict < Shared::Public::ConflictError
  end
end
