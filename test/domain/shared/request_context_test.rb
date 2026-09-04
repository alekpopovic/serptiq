# frozen_string_literal: true

require "test_helper"

class RequestContextTest < ActiveSupport::TestCase
  setup { Shared::Observability::Context.reset }
  teardown { Shared::Observability::Context.reset }

  test "is mounted immediately after Rails request ID middleware" do
    stack = Rails.application.middleware.map(&:klass)

    request_id_index = stack.index(ActionDispatch::RequestId)
    context_index = stack.index(Shared::Observability::RequestContext)
    assert_equal request_id_index + 1, context_index
  end

  test "attaches request trace release and environment context then clears it" do
    snapshots = []
    app = lambda do |_environment|
      snapshots << Shared::Observability::Context.snapshot
      [ 204, {}, [] ]
    end
    middleware = Shared::Observability::RequestContext.new(
      app,
      runtime_attributes: { release: "release-123", environment: "test" }
    )
    trace_id = "a" * 32

    response = middleware.call(
      "action_dispatch.request_id" => "request-123",
      "HTTP_TRACEPARENT" => "00-#{trace_id}-#{'b' * 16}-01"
    )

    assert_equal 204, response.first
    assert_equal "request-123", snapshots.first.fetch("request_id")
    assert_equal trace_id, snapshots.first.fetch("trace_id")
    assert_equal "release-123", snapshots.first.fetch("release")
    assert_empty Shared::Observability::Context.snapshot
  end

  test "does not carry stale or hostile correlation values between requests" do
    snapshots = []
    app = lambda do |_environment|
      snapshots << Shared::Observability::Context.snapshot
      [ 200, {}, [] ]
    end
    generated = %w[generated-first generated-second]
    middleware = Shared::Observability::RequestContext.new(
      app,
      runtime_attributes: { release: "release-123", environment: "test" },
      uuid_generator: -> { generated.shift }
    )
    Shared::Observability::Context.request_id = "stale-request"

    middleware.call("HTTP_X_REQUEST_ID" => "contains spaces and customer data")
    middleware.call({})

    assert_equal %w[generated-first generated-second], snapshots.map { |snapshot| snapshot.fetch("request_id") }
    assert snapshots.none? { |snapshot| snapshot.value?("stale-request") }
    assert_empty Shared::Observability::Context.snapshot
  end

  test "clears context when the downstream application raises" do
    middleware = Shared::Observability::RequestContext.new(
      ->(_environment) { raise "synthetic request failure" },
      runtime_attributes: { release: "release-123", environment: "test" }
    )

    assert_raises(RuntimeError) { middleware.call("HTTP_X_REQUEST_ID" => "request-123") }
    assert_empty Shared::Observability::Context.snapshot
  end
end
