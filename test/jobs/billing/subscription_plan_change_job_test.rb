# frozen_string_literal: true

require "test_helper"

class BillingSubscriptionPlanChangeJobTest < ActiveSupport::TestCase
  class CapturingSubmitter
    attr_reader :calls

    def initialize
      @calls = []
    end

    def call(**attributes)
      calls << attributes
    end
  end

  setup do
    @previous_builder = Billing::SubscriptionPlanChangeJob.submitter_builder
    @submitter = CapturingSubmitter.new
    Billing::SubscriptionPlanChangeJob.submitter_builder = -> { @submitter }
  end

  teardown do
    Billing::SubscriptionPlanChangeJob.submitter_builder = @previous_builder
  end

  test "passes only explicit tenant and durable change identifiers to the submitter" do
    organization_id = SecureRandom.uuid
    change_id = SecureRandom.uuid

    Billing::SubscriptionPlanChangeJob.perform_now(
      organization_id: organization_id,
      subscription_change_id: change_id
    )

    assert_equal [ {
      organization_id: organization_id,
      subscription_change_id: change_id
    } ], @submitter.calls
  end
end
