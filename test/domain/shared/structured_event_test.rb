# frozen_string_literal: true

require "test_helper"
require "json"

class StructuredEventTest < ActiveSupport::TestCase
  class CaptureLogger
    attr_reader :entries

    def initialize
      @entries = []
    end

    %i[debug info warn error fatal].each do |severity|
      define_method(severity) { |message| entries << [ severity, message ] }
    end
  end

  setup { Shared::Observability::Context.reset }
  teardown { Shared::Observability::Context.reset }

  test "emits versioned JSON with bounded correlation and safe resource identifiers" do
    logger = CaptureLogger.new
    clock = -> { Time.utc(2026, 9, 4, 3, 0, 0) }
    emitter = Shared::Observability::EventEmitter.new(logger: logger, clock: clock)
    organization_id = "8a91c232-a9fa-4f20-8dd4-c0c597619e34"
    project_id = "71849ac6-b79b-4e8c-a72e-bd984c40f1c9"

    record = Shared::Observability::Context.set(
      request_id: "request-123",
      trace_id: "a" * 32,
      release: "release-abc",
      environment: "test"
    ) do
      Shared::Observability::Context.attach_resources(
        organization_id: organization_id,
        project_id: project_id,
        identifier_hasher: Shared::Observability::IdentifierHasher.new(secret: "test-observability-secret")
      )
      emitter.emit(
        "crawler.destination_rejected",
        severity: :warn,
        outcome: "denied",
        reason_code: "private_address",
        duration_ms: 12.5
      )
    end

    assert_equal "2026-09-04T03:00:00.000000Z", record.fetch("timestamp")
    assert_equal 1, record.fetch("event_version")
    assert_equal "request-123", record.fetch("request_id")
    assert_equal project_id, record.fetch("project_id")
    assert_match(/\A[0-9a-f]{24}\z/, record.fetch("organization_id_hash"))
    refute_includes JSON.generate(record), organization_id
    assert_equal record, JSON.parse(logger.entries.one? ? logger.entries.first.last : "{}")
  end

  test "rejects customer-controlled names labels and prohibited payload fields" do
    emitter = Shared::Observability::EventEmitter.new(logger: CaptureLogger.new)

    assert_raises(ArgumentError) { emitter.emit("customer supplied event") }
    assert_raises(ArgumentError) { emitter.emit("scan.finished", provider: "customer/value/#{'x' * 80}") }
    assert_raises(ArgumentError) { emitter.emit("scan.finished", page_body: "private html") }
    assert_raises(ArgumentError) { emitter.emit("scan.finished", retry_count: -1) }
  end

  test "rejects resource labels that are not application UUIDs" do
    assert_raises(ArgumentError) do
      Shared::Observability::Context.attach_resources(project_id: "customer-project-name")
    end
  end

  test "rejects directly assigned raw tenant context" do
    Shared::Observability::Context.organization_id_hash = "raw-organization-id"
    emitter = Shared::Observability::EventEmitter.new(logger: CaptureLogger.new)

    assert_raises(ArgumentError) { emitter.emit("scan.finished") }
  end
end
