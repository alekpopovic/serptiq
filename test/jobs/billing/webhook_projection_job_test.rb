# frozen_string_literal: true

require "test_helper"

class BillingWebhookProjectionJobTest < ActiveSupport::TestCase
  class RecordingProcessor
    attr_reader :ids

    def initialize
      @ids = []
    end

    def call(webhook_event_id:)
      ids << webhook_event_id
      Billing::WebhookProjectionOutcome.new(result: "stale")
    end
  end

  setup do
    @previous_builder = Billing::WebhookProjectionJob.processor_builder
    @processor = RecordingProcessor.new
    Billing::WebhookProjectionJob.processor_builder = -> { @processor }
  end

  teardown do
    Billing::WebhookProjectionJob.processor_builder = @previous_builder
  end

  test "passes only the durable event ID and remains safe when the queue delivers twice" do
    event_id = SecureRandom.uuid

    2.times { Billing::WebhookProjectionJob.perform_now(webhook_event_id: event_id) }

    assert_equal [ event_id, event_id ], @processor.ids
  end
end
