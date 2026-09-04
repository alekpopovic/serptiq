# frozen_string_literal: true

require "test_helper"

class SharedErrorsTest < ActiveSupport::TestCase
  EXPECTED = {
    Shared::Errors::ValidationError => [ "validation", "validation_failed", 422 ],
    Shared::Errors::AuthenticationError => [ "authentication", "authentication_required", 401 ],
    Shared::Errors::AuthorizationError => [ "authorization", "authorization_denied", 403 ],
    Shared::Errors::EntitlementError => [ "entitlement", "entitlement_required", 403 ],
    Shared::Errors::QuotaError => [ "quota", "quota_exceeded", 429 ],
    Shared::Errors::RateLimitError => [ "rate_limit", "rate_limited", 429 ],
    Shared::Errors::ConflictError => [ "conflict", "resource_conflict", 409 ],
    Shared::Errors::ExternalProviderError => [ "external_provider", "external_provider_failed", 502 ],
    Shared::Errors::TransientInfrastructureError =>
      [ "transient_infrastructure", "service_temporarily_unavailable", 503 ],
    Shared::Errors::UnsafeDestinationError => [ "unsafe_destination", "unsafe_destination", 422 ]
  }.freeze

  test "defines stable public mappings for every expected domain category" do
    EXPECTED.each do |error_class, expected|
      error = error_class.new("operator-only detail")
      response = Shared::Errors.http_response_for(error)

      assert_equal expected, [ response.category, response.public_code, response.http_status ]
      assert response.expected
      refute_includes response.public_message, "operator-only"
    end
  end

  test "maps unexpected exceptions and explicit internal faults to one safe response" do
    [ RuntimeError.new("database password secret"), Shared::Errors::InternalFault.new("private detail") ].each do |error|
      response = Shared::Errors.http_response_for(error)

      assert_equal [ "internal_fault", "internal_error", 500 ],
        [ response.category, response.public_code, response.http_status ]
      refute response.expected
      refute_match(/password|private|secret/i, response.public_message)
    end
  end

  test "accepts only stable reason codes" do
    error = Shared::Errors::QuotaError.new(reason_code: "monthly_credit_limit")

    assert_equal "monthly_credit_limit", error.reason_code
    assert_raises(ArgumentError) do
      Shared::Errors::QuotaError.new(reason_code: "customer supplied reason 123")
    end
  end

  test "records a bounded cause class chain without recording messages" do
    error = error_with_cause

    assert_equal [ "IOError" ], Shared::Errors.cause_classes(error)
    refute_includes Shared::Errors.cause_classes(error).join, "provider token"
  end

  test "existing job failures participate in the shared taxonomy" do
    assert_equal "transient_infrastructure", Shared::JobErrors::TransientInfrastructure.new.definition.category
    assert_equal "external_provider", Shared::JobErrors::TransientProvider.new.definition.category
    assert_equal "quota", Shared::JobErrors::QuotaRejected.new.definition.category
    assert_equal "unsafe_destination", Shared::JobErrors::SecurityRejected.new.definition.category
  end

  private

  def error_with_cause
    cause = begin
      raise IOError, "provider token must never be logged"
    rescue IOError => error
      error
    end

    begin
      raise Shared::Errors::ExternalProviderError, "operator detail", cause: cause
    rescue Shared::Errors::ExternalProviderError => error
      error
    end
  end
end
