# frozen_string_literal: true

module Crawling
  module ArtifactStore
    Upload = Data.define(:byte_count, :content_sha256, :encryption_mode, :encryption_key_version)
    ObjectEntry = Data.define(:key, :byte_count, :last_modified_at)
    Page = Data.define(:entries, :cursor) do
      def completed?
        cursor.nil?
      end
    end

    class Error < Shared::Public::TransientInfrastructureError; end
    class IntegrityError < Error; end
    class MissingObject < Error; end

    module Contract
      def upload(**) = raise(NotImplementedError)
      def download(**) = raise(NotImplementedError)
      def exist?(**) = raise(NotImplementedError)
      def delete(**) = raise(NotImplementedError)
      def list(**) = raise(NotImplementedError)
      def signed_url(**) = raise(NotImplementedError)
    end
  end
end
