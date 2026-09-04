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

  test "public boundary distinguishes users with and without an active organization membership" do
    user = create_identity_user
    status = Tenancy::Public.first_run_status(user: user)

    assert status.no_organization?
    create_organization_for(user: user, slug: "returning-user-org")
    assert Tenancy::Public.first_run_status(user: user).returning?

    assert_raises(ArgumentError) do
      Tenancy::Public.first_run_status(user: create_identity_user(suspended_at: Time.current))
    end
  end
end
