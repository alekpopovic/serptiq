# frozen_string_literal: true

module Crawling
  class Artifact < ApplicationRecord
    self.table_name = "artifacts"

    RETENTION_STATES = %w[retained deletion_pending missing deleted].freeze
    IDENTIFIER_PATTERN = /\A[a-z][a-z0-9_]{0,47}\z/
    MEDIA_TYPE_PATTERN = /\A[a-z0-9!#$&^_.+-]+\/[a-z0-9!#$&^_.+-]+\z/

    belongs_to :blob, class_name: "Crawling::ArtifactBlob", foreign_key: :artifact_blob_id,
      inverse_of: :artifacts
    belongs_to :scan, class_name: "Crawling::Scan", inverse_of: :artifacts

    validates :organization_id, :project_id, :property_id, :environment_id, :scan_id,
      :source_id, :download_filename, :retention_expires_at, presence: true
    validates :source_type, :kind, :retention_class, format: { with: IDENTIFIER_PATTERN }
    validates :media_type, format: { with: MEDIA_TYPE_PATTERN }
    validates :source_id, length: { maximum: 128 }, format: { without: /[[:cntrl:]]/ }
    validates :download_filename, length: { maximum: 160 },
      format: { without: %r{[[:cntrl:]/\\]} }
    validates :retention_state, inclusion: { in: RETENTION_STATES }
    validate :identifier_shapes
    validate :legal_hold_shape
    validate :retention_lifecycle

    scope :retained, -> { where(retention_state: "retained") }

    def downloadable?
      retention_state == "retained" && blob.active?
    end

    private

    def identifier_shapes
      %i[organization_id project_id property_id environment_id scan_id artifact_blob_id].each do |name|
        errors.add(name, "is invalid") unless Shared::Public.application_uuid?(public_send(name))
      end
    end

    def legal_hold_shape
      valid = legal_hold ? legal_hold_set_at.present? : legal_hold_set_at.nil?
      errors.add(:legal_hold, "does not match its timestamp") unless valid
    end

    def retention_lifecycle
      valid = retention_state == "retained" ? deletion_requested_at.nil? : deletion_requested_at.present?
      valid &&= deleted_at.present? if retention_state == "deleted"
      errors.add(:retention_state, "does not match lifecycle timestamps") unless valid
    end
  end
end
