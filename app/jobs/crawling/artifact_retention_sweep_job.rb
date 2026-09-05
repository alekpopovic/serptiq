# frozen_string_literal: true

module Crawling
  class ArtifactRetentionSweepJob < ApplicationJob
    class_attribute :expirer_builder, default: -> { ExpireArtifacts.new }

    runs_on :maintenance
    system_authorization :artifact_retention_sweep,
      reason: "queues a bounded batch of expired private artifacts outside legal hold"

    def perform
      self.class.expirer_builder.call.call.each do |artifact_id|
        ArtifactDeletionJob.perform_later(artifact_id: artifact_id)
      end
    end
  end
end
