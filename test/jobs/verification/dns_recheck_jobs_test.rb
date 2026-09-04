# frozen_string_literal: true

require "test_helper"

class VerificationDnsRecheckJobsTest < ActiveJob::TestCase
  Rechecker = Struct.new(:calls, keyword_init: true) do
    def call(**attributes)
      calls << attributes
    end
  end
  Scheduler = Struct.new(:calls, keyword_init: true) do
    def call
      calls << true
    end
  end

  setup do
    @previous_rechecker = Verification::DnsRecheckJob.rechecker_builder
    @previous_scheduler = Verification::DnsRecheckSweepJob.scheduler_builder
  end

  teardown do
    Verification::DnsRecheckJob.rechecker_builder = @previous_rechecker
    Verification::DnsRecheckSweepJob.scheduler_builder = @previous_scheduler
  end

  test "recheck job passes only explicit durable tenant and challenge identifiers" do
    rechecker = Rechecker.new(calls: [])
    Verification::DnsRecheckJob.rechecker_builder = -> { rechecker }
    organization_id = SecureRandom.uuid
    challenge_id = SecureRandom.uuid

    2.times do
      Verification::DnsRecheckJob.perform_now(
        organization_id: organization_id,
        challenge_id: challenge_id
      )
    end

    assert_equal 2, rechecker.calls.length
    assert rechecker.calls.all? do |call|
      call == { organization_id: organization_id, challenge_id: challenge_id }
    end
    assert_equal "maintenance", Verification::DnsRecheckJob.new.queue_name
  end

  test "recurring sweep delegates to the bounded scheduler" do
    scheduler = Scheduler.new(calls: [])
    Verification::DnsRecheckSweepJob.scheduler_builder = -> { scheduler }

    Verification::DnsRecheckSweepJob.perform_now

    assert_equal [ true ], scheduler.calls
    assert_equal "maintenance", Verification::DnsRecheckSweepJob.new.queue_name
  end
end
