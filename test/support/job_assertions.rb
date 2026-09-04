# frozen_string_literal: true

module TestSupport
  module JobAssertions
    include ActiveJob::TestHelper

    def assert_job_enqueued(job:, queue:, args: nil, &block)
      expected = { job: job, queue: queue.to_s }
      expected[:args] = args unless args.nil?
      assert_enqueued_with(**expected, &block)
    end

    def assert_idempotent_retry(snapshot:, &operation)
      operation.call
      first_state = snapshot.call
      operation.call
      assert_equal first_state, snapshot.call, "retry changed state after the first successful application"
    end
  end
end
