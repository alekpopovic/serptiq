# frozen_string_literal: true

module Entitlements
  DiagnosticReport = Data.define(:entries, :plan_label, :subscription_revision) do
    def initialize(entries:, plan_label:, subscription_revision:)
      super(
        entries: entries.freeze,
        plan_label: plan_label.to_s.freeze,
        subscription_revision: subscription_revision
      )
      freeze
    end
  end
end
