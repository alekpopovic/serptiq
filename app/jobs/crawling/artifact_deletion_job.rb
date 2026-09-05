# frozen_string_literal: true

module Crawling
  class ArtifactDeletionJob < ApplicationJob
    class_attribute :deletion_builder, default: -> { DeleteArtifact.new }

    runs_on :maintenance
    system_authorization :artifact_deletion,
      reason: "deletes one retention-eligible private artifact idempotently"

    def perform(artifact_id:)
      self.class.deletion_builder.call.call(artifact_id: artifact_id)
    end
  end
end
