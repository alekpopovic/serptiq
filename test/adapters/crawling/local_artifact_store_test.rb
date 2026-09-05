# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class CrawlingLocalArtifactStoreTest < ActiveSupport::TestCase
  setup do
    @directory = Dir.mktmpdir("searchops-artifacts")
    @store = Crawling::Artifacts::LocalArtifactStore.new(
      root: @directory, origin: "https://searchops.test",
      token_codec: Crawling::LocalArtifactToken.new(secret: "x" * 64)
    )
    @key = Crawling::ArtifactKey.generate(
      organization_id: SecureRandom.uuid, project_id: SecureRandom.uuid, property_id: SecureRandom.uuid
    )
    @body = ("private artifact\n" * 10_000).b
    @digest = Digest::SHA256.hexdigest(@body)
  end

  teardown do
    FileUtils.remove_entry_secure(@directory) if File.directory?(@directory)
  end

  test "streams an atomic private upload and download" do
    result = @store.upload(
      key: @key, io: StringIO.new(@body), byte_count: @body.bytesize,
      content_sha256: @digest, media_type: "text/html", encryption_key_version: "v1"
    )

    assert_equal @body.bytesize, result.byte_count
    assert_equal @body, @store.download(key: @key).to_a.join
    assert @store.exist?(key: @key)
    path = Pathname(@directory).join(@key)
    assert_equal "600", (path.stat.mode & 0o777).to_s(8)
    assert_equal "700", (Pathname(@directory).stat.mode & 0o777).to_s(8)
  end

  test "discards a partial integrity failure and permits retry" do
    assert_raises(Crawling::ArtifactStore::IntegrityError) do
      @store.upload(
        key: @key, io: StringIO.new(@body.byteslice(0, 12)), byte_count: @body.bytesize,
        content_sha256: @digest, media_type: "text/html", encryption_key_version: "v1"
      )
    end
    refute @store.exist?(key: @key)
    assert_empty Dir.glob(Pathname(@directory).join("**", ".upload-*"))

    @store.upload(
      key: @key, io: StringIO.new(@body), byte_count: @body.bytesize,
      content_sha256: @digest, media_type: "text/html", encryption_key_version: "v1"
    )
    assert_equal @body, @store.download(key: @key).to_a.join
  end

  test "uses encrypted short lived local URLs without leaking storage keys" do
    url = @store.signed_url(
      key: @key, artifact_id: SecureRandom.uuid, expires_in: 60,
      filename: "../../customer\r\nsecret.html", media_type: "text/html"
    )

    assert_match %r{\Ahttps://searchops\.test/private-artifacts/}, url
    refute_includes url, @key
    refute_includes url, "customer"
    assert_equal "customer-secret.html", Crawling::ArtifactFilename.sanitize("../../customer\r\nsecret.html")
  end

  test "rejects expired or modified local bearer tokens" do
    at = Time.current.change(usec: 0)
    codec = Crawling::LocalArtifactToken.new(secret: "y" * 64, clock: -> { at })
    token = codec.issue(key: @key, artifact_id: SecureRandom.uuid, expires_in: 30)
    assert_equal @key, codec.read(token).fetch("key")

    expired = Crawling::LocalArtifactToken.new(secret: "y" * 64, clock: -> { at + 31.seconds })
    assert_raises(ActiveSupport::MessageEncryptor::InvalidMessage) { expired.read(token) }
    assert_raises(ActiveSupport::MessageEncryptor::InvalidMessage) { codec.read("#{token}x") }
  end

  test "lists and deletes only the exact opaque prefix" do
    @store.upload(
      key: @key, io: StringIO.new(@body), byte_count: @body.bytesize,
      content_sha256: @digest, media_type: "text/html", encryption_key_version: "v1"
    )
    prefix = @key.split("objects/").first
    assert_equal [ @key ], @store.list(prefix: prefix).entries.map(&:key)
    assert @store.delete_prefix(prefix: prefix).completed?
    refute @store.objects_remaining?(prefix: prefix)
    assert_raises(Crawling::ArtifactStore::Error) { @store.list(prefix: "organizations/") }
  end
end
