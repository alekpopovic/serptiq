# frozen_string_literal: true

module Crawling
  class ArtifactBlob < ApplicationRecord
    self.table_name = "artifact_blobs"

    STATES = %w[uploading active missing deleting deleted].freeze
    ENCRYPTION_MODES = %w[provider_managed sse_s3 local_private].freeze
    DIGEST_PATTERN = /\A[0-9a-f]{64}\z/
    VERSION_PATTERN = /\A[A-Za-z0-9][A-Za-z0-9._-]{0,63}\z/

    has_many :artifacts, class_name: "Crawling::Artifact", inverse_of: :blob,
      foreign_key: :artifact_blob_id, dependent: :restrict_with_exception

    validates :organization_id, :project_id, :property_id, :storage_service, :object_key,
      :encryption_mode, :encryption_key_version, :state, presence: true
    validates :byte_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :content_sha256, format: { with: DIGEST_PATTERN }
    validates :encryption_mode, inclusion: { in: ENCRYPTION_MODES }
    validates :encryption_key_version, format: { with: VERSION_PATTERN }
    validates :state, inclusion: { in: STATES }
    validate :identifier_shapes
    validate :scoped_opaque_key
    validate :lifecycle_shape

    scope :live, -> { where.not(state: "deleted") }

    def active?
      state == "active"
    end

    private

    def identifier_shapes
      %i[organization_id project_id property_id].each do |name|
        errors.add(name, "is invalid") unless Shared::Public.application_uuid?(public_send(name))
      end
    end

    def scoped_opaque_key
      prefix = ArtifactKey.prefix(
        organization_id: organization_id, project_id: project_id, property_id: property_id
      )
      valid = object_key.to_s.start_with?("#{prefix}objects/") && object_key.to_s.bytesize <= 512 &&
        !object_key.to_s.match?(/[[:cntrl:]]/)
      errors.add(:object_key, "is not an opaque key in the artifact scope") unless valid
    rescue ArgumentError
      errors.add(:object_key, "is invalid")
    end

    def lifecycle_shape
      valid = case state
      when "uploading" then stored_at.nil? && missing_at.nil? && deleted_at.nil?
      when "active" then stored_at.present? && missing_at.nil? && deleted_at.nil?
      when "missing" then stored_at.present? && missing_at.present? && deleted_at.nil?
      when "deleting" then stored_at.present? && deleted_at.nil?
      when "deleted" then deleted_at.present?
      else false
      end
      errors.add(:state, "does not match lifecycle timestamps") unless valid
    end
  end
end
