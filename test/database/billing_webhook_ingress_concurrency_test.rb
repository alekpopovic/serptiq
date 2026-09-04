# frozen_string_literal: true

require "test_helper"

class BillingWebhookIngressConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    Billing::WebhookEvent.delete_all
    @now = Time.utc(2026, 9, 4, 18)
    @provider = Billing::FakeProvider.new(clock: -> { @now })
  end

  teardown { Billing::WebhookEvent.delete_all }

  test "concurrent duplicate delivery converges on one durable record" do
    results = concurrently([ body, body ])

    assert_equal %w[accepted duplicate], results.map(&:status).sort
    event = Billing::WebhookEvent.sole
    assert_equal 1, event.duplicate_count
    assert_equal 0, event.conflict_count
  end

  test "concurrent logical duplicate with changed bytes records a conflict without overwrite" do
    original = body
    modified = body(metadata: { "changed" => true })
    results = concurrently([ original, modified ])

    assert_equal [ "accepted", "conflict" ], results.map(&:status).sort
    event = Billing::WebhookEvent.sole
    assert_equal 0, event.duplicate_count
    assert_equal 1, event.conflict_count
    assert_includes [ original, modified ], event.payload
    assert_equal 1, Billing::WebhookEvent.count
  end

  test "database rejects duplicate provider identity and invalid lifecycle" do
    receiver.call(raw_body: body, headers: headers)
    event = Billing::WebhookEvent.sole

    assert_raises(ActiveRecord::RecordNotUnique) do
      Billing::WebhookEvent.insert_all!([ event.attributes.except("id").merge("id" => SecureRandom.uuid) ])
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      event.update_columns(state: "processed", processed_at: @now)
    end
  end

  private

  def concurrently(bodies)
    start = Queue.new
    ready = Queue.new
    results = Queue.new
    threads = bodies.map do |payload|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          results << receiver.call(raw_body: payload, headers: headers)
        rescue StandardError => error
          results << error
        end
      end
    end
    bodies.length.times { ready.pop }
    bodies.length.times { start << true }
    threads.each(&:join)
    values = bodies.length.times.map { results.pop }
    failures = values.grep(Exception)
    flunk(failures.map(&:full_message).join("\n")) if failures.any?
    values
  end

  def receiver
    Billing::ReceiveWebhook.new(
      provider: @provider,
      environment: "test",
      clock: -> { @now },
      enqueue: ->(_) { }
    )
  end

  def headers
    { "X-Fake-Signature" => "valid", "Content-Type" => "application/json" }
  end

  def body(metadata: {})
    JSON.generate(
      id: "event-concurrent-001",
      name: "subscription.updated",
      occurred_at: @now.iso8601,
      metadata: metadata
    )
  end
end
