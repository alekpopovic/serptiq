# frozen_string_literal: true

require "digest"
require "fileutils"

module Crawling
  module Artifacts
    class LocalArtifactStore
      include ArtifactStore::Contract

      CHUNK_BYTES = 64.kilobytes
      DELETE_BATCH_SIZE = 1000

      def initialize(root:, origin:, token_codec: LocalArtifactToken.new)
        @root = Pathname(root).expand_path
        @origin = origin.to_s.delete_suffix("/")
        @token_codec = token_codec
        FileUtils.mkdir_p(@root, mode: 0o700)
        FileUtils.chmod(0o700, @root)
      end

      def upload(key:, io:, byte_count:, content_sha256:, media_type:, encryption_key_version:)
        path = path_for(key)
        FileUtils.mkdir_p(path.dirname, mode: 0o700)
        temporary = path.dirname.join(".upload-#{SecureRandom.uuid}")
        observed_bytes = 0
        digest = Digest::SHA256.new
        File.open(temporary, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
          while (chunk = io.read(CHUNK_BYTES))
            break if chunk.empty?

            file.write(chunk)
            observed_bytes += chunk.bytesize
            digest.update(chunk)
          end
          file.flush
          file.fsync
        end
        verify_upload!(observed_bytes, digest.hexdigest, byte_count, content_sha256)
        File.rename(temporary, path)
        FileUtils.chmod(0o600, path)
        ArtifactStore::Upload.new(observed_bytes, digest.hexdigest, "local_private", encryption_key_version.to_s)
      rescue ArtifactStore::IntegrityError
        raise
      rescue StandardError => error
        raise ArtifactStore::Error.new(reason_code: "artifact_upload_failed"), cause: error
      ensure
        FileUtils.rm_f(temporary) if defined?(temporary) && temporary
      end

      def download(key:)
        return enum_for(__method__, key: key) unless block_given?

        File.open(path_for(key), "rb") do |file|
          while (chunk = file.read(CHUNK_BYTES))
            yield chunk
          end
        end
      rescue Errno::ENOENT => error
        raise ArtifactStore::MissingObject.new(reason_code: "artifact_object_missing"), cause: error
      rescue ArtifactStore::Error
        raise
      rescue StandardError => error
        raise ArtifactStore::Error.new(reason_code: "artifact_download_failed"), cause: error
      end

      def exist?(key:)
        File.file?(path_for(key))
      end

      def delete(key:)
        FileUtils.rm_f(path_for(key))
        true
      rescue StandardError => error
        raise ArtifactStore::Error.new(reason_code: "artifact_delete_failed"), cause: error
      end

      def list(prefix:, cursor: nil, limit: DELETE_BATCH_SIZE)
        prefix_path = prefix_path_for(prefix)
        return ArtifactStore::Page.new([].freeze, nil) unless prefix_path.exist?

        entries = Dir.glob(prefix_path.join("**", "*"), File::FNM_DOTMATCH).filter_map do |name|
          next unless File.file?(name)
          next if File.basename(name).start_with?(".upload-")

          path = Pathname(name)
          key = path.relative_path_from(@root).to_s
          stat = path.stat
          ArtifactStore::ObjectEntry.new(key, stat.size, stat.mtime.utc)
        end.sort_by(&:key)
        entries = entries.drop_while { |entry| cursor && entry.key <= cursor.to_s }.first(Integer(limit))
        more = entries.length == Integer(limit) && remaining_after?(prefix_path, entries.last.key)
        ArtifactStore::Page.new(entries.freeze, more ? entries.last.key : nil)
      rescue ArtifactStore::Error
        raise
      rescue StandardError => error
        raise ArtifactStore::Error.new(reason_code: "artifact_list_failed"), cause: error
      end

      def delete_prefix(prefix:, cursor: nil)
        page = list(prefix: prefix, cursor: cursor)
        page.entries.each { |entry| delete(key: entry.key) }
        ArtifactStore::Page.new(page.entries, page.cursor)
      end

      def objects_remaining?(prefix:)
        list(prefix: prefix, limit: 1).entries.any?
      end

      def signed_url(key:, artifact_id:, expires_in:, filename:, media_type:)
        path_for(key)
        token = @token_codec.issue(key: key, artifact_id: artifact_id, expires_in: expires_in)
        "#{@origin}/private-artifacts/#{CGI.escape(token)}"
      end

      private

      def path_for(key)
        raise ArgumentError, "artifact key is invalid" unless ArtifactKey.valid?(key)

        path = @root.join(key).cleanpath
        raise ArgumentError, "artifact key escapes its private root" unless path.to_s.start_with?("#{@root}/")

        path
      end

      def prefix_path_for(prefix)
        value = prefix.to_s
        raise ArgumentError, "artifact prefix is invalid" unless ArtifactKey.valid_prefix?(value)

        @root.join(value).cleanpath
      end

      def verify_upload!(observed_bytes, observed_digest, expected_bytes, expected_digest)
        valid = observed_bytes == Integer(expected_bytes) &&
          ActiveSupport::SecurityUtils.secure_compare(observed_digest, expected_digest.to_s)
        raise ArtifactStore::IntegrityError.new(reason_code: "artifact_integrity_mismatch") unless valid
      end

      def remaining_after?(prefix_path, key)
        Dir.glob(prefix_path.join("**", "*"), File::FNM_DOTMATCH).any? do |name|
          File.file?(name) && !File.basename(name).start_with?(".upload-") &&
            Pathname(name).relative_path_from(@root).to_s > key
        end
      end
    end
  end
end
