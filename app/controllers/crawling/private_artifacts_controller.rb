# frozen_string_literal: true

module Crawling
  class PrivateArtifactsController < ActionController::Base
    rescue_from ActiveSupport::MessageEncryptor::InvalidMessage, with: :not_found
    rescue_from ArtifactStore::MissingObject, with: :not_found

    def show
      payload = LocalArtifactToken.new.read(params.require(:token))
      artifact = Artifact.includes(:blob).find_by(id: payload.fetch("artifact_id"))
      return not_found unless artifact&.downloadable? && artifact.blob.object_key == payload.fetch("key")

      response.headers["Content-Type"] = artifact.media_type
      response.headers["Content-Disposition"] = ArtifactFilename.content_disposition(artifact.download_filename)
      response.headers["Content-Length"] = artifact.blob.byte_count.to_s
      response.headers["Cache-Control"] = "private, no-store"
      response.headers["X-Content-Type-Options"] = "nosniff"
      self.response_body = Enumerator.new do |stream|
        ArtifactStoreFactory.build.download(key: artifact.blob.object_key) { |chunk| stream << chunk }
      end
    end

    private

    def not_found
      head :not_found
    end
  end
end
