# frozen_string_literal: true

require "digest"

module TestSupport
  class FakeArtifactStore
    include Crawling::ArtifactStore::Contract

    attr_accessor :fail_after_bytes, :fail_delete
    attr_reader :upload_attempts, :deleted_keys

    def initialize
      @objects = {}
      @upload_attempts = 0
      @deleted_keys = []
    end

    def upload(key:, io:, byte_count:, content_sha256:, media_type:, encryption_key_version:)
      @upload_attempts += 1
      buffer = +"".b
      while (chunk = io.read(7))
        break if chunk.empty?

        buffer << chunk
        if fail_after_bytes && buffer.bytesize >= fail_after_bytes
          raise Crawling::ArtifactStore::Error.new(reason_code: "synthetic_partial_upload")
        end
      end
      digest = Digest::SHA256.hexdigest(buffer)
      unless buffer.bytesize == byte_count && digest == content_sha256
        raise Crawling::ArtifactStore::IntegrityError.new(reason_code: "artifact_integrity_mismatch")
      end

      @objects[key] = { body: buffer.freeze, media_type: media_type, modified_at: Time.current }
      Crawling::ArtifactStore::Upload.new(byte_count, digest, "provider_managed", encryption_key_version)
    end

    def download(key:)
      return enum_for(__method__, key: key) unless block_given?

      object = @objects.fetch(key) do
        raise Crawling::ArtifactStore::MissingObject.new(reason_code: "artifact_object_missing")
      end
      object.fetch(:body).scan(/.{1,5}/m) { |chunk| yield chunk }
    end

    def exist?(key:)
      @objects.key?(key)
    end

    def delete(key:)
      raise Crawling::ArtifactStore::Error.new(reason_code: "synthetic_delete_failure") if fail_delete

      @deleted_keys << key
      @objects.delete(key)
      true
    end

    def list(prefix:, cursor: nil, limit: 1000)
      keys = @objects.keys.select { |key| key.start_with?(prefix) }.sort
      keys = keys.drop_while { |key| cursor && key <= cursor }.first(limit)
      entries = keys.map do |key|
        object = @objects.fetch(key)
        Crawling::ArtifactStore::ObjectEntry.new(key, object.fetch(:body).bytesize, object.fetch(:modified_at))
      end
      remaining = @objects.keys.any? { |key| key.start_with?(prefix) && keys.last && key > keys.last }
      Crawling::ArtifactStore::Page.new(entries, remaining ? keys.last : nil)
    end

    def delete_prefix(prefix:, cursor: nil)
      page = list(prefix: prefix, cursor: cursor)
      page.entries.each { |entry| delete(key: entry.key) }
      page
    end

    def objects_remaining?(prefix:)
      @objects.keys.any? { |key| key.start_with?(prefix) }
    end

    def signed_url(key:, artifact_id:, expires_in:, filename:, media_type:)
      raise Crawling::ArtifactStore::MissingObject.new(reason_code: "artifact_object_missing") unless exist?(key: key)

      opaque = Digest::SHA256.hexdigest([ key, artifact_id, expires_in, filename, media_type ].join("\0"))
      "https://objects.example.test/private/#{opaque}"
    end

    def seed(key, body)
      @objects[key] = { body: body.b.freeze, media_type: "application/octet-stream", modified_at: Time.current }
    end

    def body(key)
      @objects.fetch(key).fetch(:body)
    end
  end
end
