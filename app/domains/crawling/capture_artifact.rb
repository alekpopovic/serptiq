# frozen_string_literal: true

require "digest"
require "tempfile"

module Crawling
  class CaptureArtifact
    MAX_BYTES = 100.megabytes

    def initialize(store: ArtifactStoreFactory.build, clock: -> { Time.current }, max_bytes: MAX_BYTES,
      key_generator: ArtifactKey.method(:generate))
      @store = store
      @clock = clock
      @max_bytes = Integer(max_bytes)
      @key_generator = key_generator
    end

    def call(organization_id:, project_id:, property_id:, environment_id:, scan_id:, source_type:, source_id:,
      kind:, media_type:, filename:, retention_class:, retention_expires_at:, io:)
      scan = exact_running_scan!(organization_id, project_id, property_id, environment_id, scan_id)
      metadata = normalize_metadata!(source_type, source_id, kind, media_type, filename,
        retention_class, retention_expires_at)
      tempfile, byte_count, digest = spool(io)
      existing = find_existing(scan, metadata)
      return reference(existing) if existing && identical?(existing, byte_count, digest)
      raise Conflict.new(reason_code: "artifact_source_conflict") if existing

      blob = find_or_create_blob(scan, byte_count, digest)
      store_blob!(blob, tempfile, metadata.fetch(:media_type))
      artifact = create_reference!(scan, blob, metadata)
      emit("succeeded", "upload", blob.storage_service)
      reference(artifact)
    rescue ActiveRecord::RecordInvalid, ArgumentError, TypeError => error
      raise Invalid.new(
        field_errors: { artifact: [ "metadata or content is invalid" ] }, reason_code: "artifact_invalid"
      ), cause: error
    rescue ArtifactStore::Error
      emit("failed", "upload", @store.class.name.demodulize.underscore)
      raise
    ensure
      tempfile&.close!
    end

    private

    def exact_running_scan!(organization_id, project_id, property_id, environment_id, scan_id)
      scan = Scan.find_by(
        organization_id: organization_id, project_id: project_id, property_id: property_id,
        environment_id: environment_id, id: scan_id
      )
      raise Conflict.new(reason_code: "artifact_scan_unavailable") unless scan && resources_available?(scan)

      scan
    end

    def normalize_metadata!(source_type, source_id, kind, media_type, filename, retention_class, expires_at)
      source = source_id.to_s
      raise ArgumentError, "source identifier cannot contain a URL" if source.include?("://") || source.include?("?")

      expiration = expires_at.to_time
      raise ArgumentError, "artifact retention must expire in the future" unless expiration > @clock.call

      metadata = {
        source_type: source_type.to_s, source_id: source, kind: kind.to_s,
        media_type: media_type.to_s.downcase,
        download_filename: ArtifactFilename.sanitize(filename), retention_class: retention_class.to_s,
        retention_expires_at: expiration
      }
      valid = %i[source_type kind retention_class].all? do |name|
        Artifact::IDENTIFIER_PATTERN.match?(metadata.fetch(name))
      end
      valid &&= source.bytesize.between?(1, 128) && !source.match?(/[[:cntrl:]]/)
      valid &&= Artifact::MEDIA_TYPE_PATTERN.match?(metadata.fetch(:media_type))
      raise ArgumentError, "artifact metadata is invalid" unless valid

      metadata
    end

    def spool(io)
      tempfile = Tempfile.new([ "searchops-artifact", ".spool" ], binmode: true)
      bytes = 0
      digest = Digest::SHA256.new
      while (chunk = io.read(64.kilobytes))
        break if chunk.empty?

        bytes += chunk.bytesize
        raise ArgumentError, "artifact exceeds its byte limit" if bytes > @max_bytes

        digest.update(chunk)
        tempfile.write(chunk)
      end
      tempfile.flush
      tempfile.rewind
      [ tempfile, bytes, digest.hexdigest ]
    rescue StandardError
      tempfile&.close!
      raise
    end

    def find_existing(scan, metadata)
      Artifact.includes(:blob).find_by(
        organization_id: scan.organization_id, project_id: scan.project_id, property_id: scan.property_id,
        source_type: metadata.fetch(:source_type), source_id: metadata.fetch(:source_id), kind: metadata.fetch(:kind)
      )
    end

    def identical?(artifact, bytes, digest)
      artifact.blob.byte_count == bytes &&
        ActiveSupport::SecurityUtils.secure_compare(artifact.blob.content_sha256, digest)
    end

    def find_or_create_blob(scan, byte_count, digest)
      key_version = Rails.application.config.x.searchops.fetch(:encryption_key_version)
      scope = {
        organization_id: scan.organization_id, project_id: scan.project_id, property_id: scan.property_id,
        encryption_key_version: key_version, content_sha256: digest
      }
      ArtifactBlob.live.find_by(scope) || ArtifactBlob.create!(
        **scope, storage_service: Rails.application.config.x.searchops.fetch(:object_storage_service),
        object_key: @key_generator.call(
          organization_id: scan.organization_id, project_id: scan.project_id, property_id: scan.property_id
        ), byte_count: byte_count, encryption_mode: encryption_mode, state: "uploading"
      )
    rescue ActiveRecord::RecordNotUnique
      ArtifactBlob.live.find_by!(scope)
    end

    def store_blob!(blob, tempfile, media_type)
      blob.with_lock do
        return if blob.active?
        raise Conflict.new(reason_code: "artifact_blob_deleting") if blob.state.in?(%w[deleting deleted])

        tempfile.rewind
        upload = @store.upload(
          key: blob.object_key, io: tempfile, byte_count: blob.byte_count,
          content_sha256: blob.content_sha256, media_type: media_type,
          encryption_key_version: blob.encryption_key_version
        )
        now = @clock.call
        blob.update!(
          state: "active", encryption_mode: upload.encryption_mode,
          stored_at: blob.stored_at || now, verified_at: now, missing_at: nil
        )
      end
    end

    def create_reference!(scan, blob, metadata)
      blob.with_lock do
        raise Conflict.new(reason_code: "artifact_blob_unavailable") unless blob.active?
        raise Conflict.new(reason_code: "artifact_scan_unavailable") unless resources_available?(scan.reload)

        Artifact.create!(
          organization_id: scan.organization_id, project_id: scan.project_id, property_id: scan.property_id,
          environment_id: scan.environment_id, scan_id: scan.id, artifact_blob_id: blob.id, **metadata
        )
      end
    rescue ActiveRecord::RecordNotUnique
      artifact = find_existing(scan, metadata)
      raise Conflict.new(reason_code: "artifact_source_conflict") unless artifact&.artifact_blob_id == blob.id

      artifact
    end

    def resources_available?(scan)
      return false unless scan.status.in?(%w[running cancel_requested])

      project = Projects::Public.reference(organization_id: scan.organization_id, project_id: scan.project_id)
      property = Properties::Public.reference(
        organization_id: scan.organization_id, project_id: scan.project_id, property_id: scan.property_id
      )
      project&.active? && property&.active?
    end

    def encryption_mode
      @store.is_a?(Artifacts::LocalArtifactStore) ? "local_private" : "provider_managed"
    end

    def reference(artifact)
      ArtifactReference.new(
        organization_id: artifact.organization_id, project_id: artifact.project_id,
        property_id: artifact.property_id, artifact_id: artifact.id
      )
    end

    def emit(outcome, operation, provider)
      Shared::Public.emit_structured_event(
        "artifact.storage", outcome: outcome, operation: operation, provider: provider.to_s.first(64)
      )
    rescue ArgumentError => error
      Shared::Public.report_observability_failure(error, event_name: "artifact.storage")
    end
  end
end
