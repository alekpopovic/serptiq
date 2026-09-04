# frozen_string_literal: true

require "test_helper"

class TenancyFirstRunStatusTest < ActiveSupport::TestCase
  test "accepts only the three explicit routing states" do
    %i[no_organization invited returning].each do |kind|
      status = Tenancy::FirstRunStatus.new(kind: kind)
      assert_equal kind, status.kind
      assert status.public_send("#{kind}?")
    end

    assert_raises(ArgumentError) { Tenancy::FirstRunStatus.new(kind: :unknown) }
  end

  test "pre-tenancy public boundary honestly routes active users without an organization" do
    status = Tenancy::Public.first_run_status(user: create_identity_user)

    assert status.no_organization?
    assert_raises(ArgumentError) do
      Tenancy::Public.first_run_status(user: create_identity_user(suspended_at: Time.current))
    end
  end
end
