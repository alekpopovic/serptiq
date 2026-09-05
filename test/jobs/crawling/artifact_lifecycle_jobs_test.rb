# frozen_string_literal: true

require "test_helper"

class CrawlingArtifactLifecycleJobsTest < ActiveJob::TestCase
  setup do
    @original_expirer = Crawling::ArtifactRetentionSweepJob.expirer_builder
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
  end

  teardown do
    Crawling::ArtifactRetentionSweepJob.expirer_builder = @original_expirer
    ActiveJob::Base.queue_adapter = @original_queue_adapter
  end

  test "jobs declare maintenance routing and system authorization" do
    expected = {
      Crawling::ArtifactDeletionJob => "artifact_deletion",
      Crawling::ArtifactRetentionSweepJob => "artifact_retention_sweep",
      Crawling::ArtifactReconciliationJob => "artifact_reconciliation"
    }
    expected.each do |job, name|
      assert_equal "maintenance", job.queue_name
      assert_equal "system", job.authorization_job_policy.fetch(:kind)
      assert_equal name, job.authorization_job_policy.fetch(:name)
      assert job.authorization_job_policy.fetch(:reason).present?
    end
  end

  test "retention sweep enqueues exact artifact identifiers" do
    ids = [ SecureRandom.uuid, SecureRandom.uuid ]
    service = Object.new
    service.define_singleton_method(:call) { ids }
    Crawling::ArtifactRetentionSweepJob.expirer_builder = -> { service }
    assert_enqueued_jobs 2, only: Crawling::ArtifactDeletionJob do
      Crawling::ArtifactRetentionSweepJob.perform_now
    end
    assert_equal ids.sort, enqueued_jobs.map { |job| job.fetch(:args).first.fetch("artifact_id") }.sort
  end
end
