# frozen_string_literal: true

module Billing
  SupportDashboard = Data.define(
    :events, :reconciliations, :mappings, :consistency_issues, :metrics, :manage_allowed
  )
end
