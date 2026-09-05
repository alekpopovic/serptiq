# frozen_string_literal: true

require "test_helper"
require "aws-sdk-s3"

class CrawlingS3ArtifactStoreTest < ActiveSupport::TestCase
  class Presigner
    attr_reader :calls

    def initialize
      @calls = []
    end

    def presigned_url(operation, **arguments)
      @calls << [ operation, arguments ]
      "https://signed.example.test/opaque"
    end
  end

  test "uploads privately with streaming body checksum and server side encryption" do
    client = Aws::S3::Client.new(stub_responses: true, region: "us-east-1")
    presigner = Presigner.new
    store = Crawling::Artifacts::S3ArtifactStore.new(client: client, presigner: presigner, bucket: "private-test")
    key = Crawling::ArtifactKey.generate(
      organization_id: SecureRandom.uuid, project_id: SecureRandom.uuid, property_id: SecureRandom.uuid
    )
    body = "bounded-stream"
    digest = Digest::SHA256.hexdigest(body)

    store.upload(
      key: key, io: StringIO.new(body), byte_count: body.bytesize, content_sha256: digest,
      media_type: "text/plain", encryption_key_version: "v7"
    )
    request = client.api_requests.fetch(0).fetch(:params)
    assert_equal "AES256", request.fetch(:server_side_encryption)
    refute request.key?(:acl)
    assert_equal body.bytesize, request.fetch(:content_length)
    assert_equal({ "key-version" => "v7" }, request.fetch(:metadata))

    assert_equal "https://signed.example.test/opaque", store.signed_url(
      key: key, artifact_id: SecureRandom.uuid, expires_in: 60, filename: "safe.txt", media_type: "text/plain"
    )
    operation, arguments = presigner.calls.sole
    assert_equal :get_object, operation
    assert_equal "private-test", arguments.fetch(:bucket)
    assert_equal key, arguments.fetch(:key)
    assert_equal 60, arguments.fetch(:expires_in)
    assert_equal "attachment; filename=\"safe.txt\"", arguments.fetch(:response_content_disposition)
  end
end
