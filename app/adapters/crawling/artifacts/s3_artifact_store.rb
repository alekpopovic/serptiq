# frozen_string_literal: true

require "base64"

module Crawling
  module Artifacts
    class S3ArtifactStore
      include ArtifactStore::Contract

      MAX_SIGNED_URL_TTL = 15.minutes

      def initialize(client:, presigner:, bucket:)
        @client = client
        @presigner = presigner
        @bucket = bucket.to_s
      end

      def upload(key:, io:, byte_count:, content_sha256:, media_type:, encryption_key_version:)
        validate_key!(key)
        @client.put_object(
          bucket: @bucket, key: key, body: io, content_length: Integer(byte_count),
          content_type: media_type, checksum_sha256: [ content_sha256 ].pack("H*").then { Base64.strict_encode64(_1) },
          server_side_encryption: "AES256", metadata: { "key-version" => encryption_key_version.to_s }
        )
        ArtifactStore::Upload.new(Integer(byte_count), content_sha256.to_s, "sse_s3", encryption_key_version.to_s)
      rescue ArgumentError, TypeError
        raise
      rescue StandardError => error
        raise_store_error(error, "artifact_upload_failed")
      end

      def download(key:)
        return enum_for(__method__, key: key) unless block_given?

        validate_key!(key)
        @client.get_object(bucket: @bucket, key: key) { |chunk| yield chunk }
      rescue StandardError => error
        raise_store_error(error, "artifact_download_failed")
      end

      def exist?(key:)
        validate_key!(key)
        @client.head_object(bucket: @bucket, key: key)
        true
      rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
        false
      rescue StandardError => error
        raise_store_error(error, "artifact_head_failed")
      end

      def delete(key:)
        validate_key!(key)
        @client.delete_object(bucket: @bucket, key: key)
        true
      rescue StandardError => error
        raise_store_error(error, "artifact_delete_failed")
      end

      def list(prefix:, cursor: nil, limit: 1000)
        raise ArgumentError, "artifact prefix is invalid" unless ArtifactKey.valid_prefix?(prefix)

        response = @client.list_objects_v2(
          bucket: @bucket, prefix: prefix, continuation_token: cursor, max_keys: [ Integer(limit), 1000 ].min
        )
        entries = response.contents.map do |object|
          ArtifactStore::ObjectEntry.new(object.key, object.size, object.last_modified)
        end
        ArtifactStore::Page.new(entries.freeze, response.is_truncated ? response.next_continuation_token : nil)
      rescue StandardError => error
        raise_store_error(error, "artifact_list_failed")
      end

      def delete_prefix(prefix:, cursor: nil)
        page = list(prefix: prefix, cursor: cursor)
        page.entries.each_slice(1000) do |entries|
          @client.delete_objects(
            bucket: @bucket, delete: { quiet: true, objects: entries.map { |entry| { key: entry.key } } }
          )
        end
        page
      rescue StandardError => error
        raise_store_error(error, "artifact_delete_failed")
      end

      def objects_remaining?(prefix:)
        list(prefix: prefix, limit: 1).entries.any?
      end

      def signed_url(key:, artifact_id:, expires_in:, filename:, media_type:)
        validate_key!(key)
        ttl = Float(expires_in)
        raise ArgumentError, "artifact URL lifetime is invalid" unless ttl.between?(1, MAX_SIGNED_URL_TTL.to_f)

        @presigner.presigned_url(
          :get_object, bucket: @bucket, key: key, expires_in: ttl.to_i,
          response_content_type: media_type,
          response_content_disposition: ArtifactFilename.content_disposition(filename)
        )
      rescue ArgumentError, TypeError
        raise
      rescue StandardError => error
        raise_store_error(error, "artifact_signing_failed")
      end

      private

      def validate_key!(key)
        raise ArgumentError, "artifact key is invalid" unless ArtifactKey.valid?(key)
      end

      def raise_store_error(error, reason)
        raise error if error.is_a?(ArtifactStore::Error)

        raise ArtifactStore::Error.new(reason_code: reason), cause: error
      end
    end
  end
end
