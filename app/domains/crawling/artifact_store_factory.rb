# frozen_string_literal: true

module Crawling
  module ArtifactStoreFactory
    module_function

    def build(settings: Rails.application.config.x.searchops)
      case settings.fetch(:object_storage_service)
      when "local"
        Artifacts::LocalArtifactStore.new(
          root: Rails.root.join("storage/private-artifacts", Rails.env),
          origin: settings.fetch(:application_origin)
        )
      when "s3"
        require "aws-sdk-s3"
        options = {
          region: settings.fetch(:object_storage_region),
          endpoint: settings.fetch(:object_storage_endpoint),
          force_path_style: settings.fetch(:object_storage_endpoint).present?
        }.compact
        access_key = settings.secret(:object_storage_access_key_id)
        secret_key = settings.secret(:object_storage_secret_access_key)
        options[:credentials] = Aws::Credentials.new(access_key, secret_key) if access_key.present? && secret_key.present?
        client = Aws::S3::Client.new(**options)
        Artifacts::S3ArtifactStore.new(
          client: client, presigner: Aws::S3::Presigner.new(client: client),
          bucket: settings.fetch(:object_storage_bucket)
        )
      else
        raise ArgumentError, "unsupported artifact storage service"
      end
    end
  end
end
