# frozen_string_literal: true

require "test_helper"

class ProviderFakeContractTest < ActiveSupport::TestCase
  test "returns scripted normalized responses and records synthetic requests" do
    fake = TestSupport::ProviderFake.new(
      exchange: [ { subject: "provider-user-1", verified: true } ]
    )

    result = fake.invoke(:exchange, code: "synthetic-code")

    assert_equal({ subject: "provider-user-1", verified: true }, result)
    assert_equal [ { operation: :exchange, request: { code: "synthetic-code" } } ], fake.calls
    assert fake.assert_exhausted!
  end

  test "raises scripted provider failures and rejects unplanned network-like calls" do
    timeout = Timeout::Error.new("synthetic timeout")
    fake = TestSupport::ProviderFake.new(profile: [ timeout ])

    assert_raises(Timeout::Error) { fake.invoke(:profile, access_token: "synthetic-token") }
    assert_raises(TestSupport::ProviderFake::UnexpectedCall) { fake.invoke(:live_provider_request) }
    assert fake.assert_exhausted!
  end
end
