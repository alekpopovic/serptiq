# frozen_string_literal: true

module Crawling
  class ArtifactReconciliationJob < ApplicationJob
    class_attribute :reconciler_builder, default: -> { ReconcileArtifacts.new }

    runs_on :maintenance
    system_authorization :artifact_reconciliation,
      reason: "checks a bounded batch of private artifact metadata against object storage"

    def perform
      self.class.reconciler_builder.call.call
    end
  end
end
