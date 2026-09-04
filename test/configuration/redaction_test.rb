# frozen_string_literal: true

require "test_helper"

class SharedRedactionTest < ActiveSupport::TestCase
  test "redacts nested parameters and structured events" do
    value = {
      "provider" => "google",
      "oauth" => {
        "code" => "oauth-code",
        "id_token" => "id-token",
        "state" => "state-value",
        "nonce" => "nonce-value",
        "pkce_verifier" => "pkce-value"
      },
      "billing" => { "webhook_secret" => "billing-secret", "raw_body" => "signed-payload" },
      "api" => { "api_key" => "api-secret" },
      "crawler" => { "page_body" => "private html", "rendered_dom" => "private dom" },
      "profile" => { "email" => "person@example.com" }
    }

    filtered = redaction.structured_event(value)

    assert_equal "google", filtered.fetch("provider")
    assert_equal "[FILTERED]", filtered.dig("oauth", "code")
    assert_equal "[FILTERED]", filtered.dig("oauth", "id_token")
    assert_equal "[FILTERED]", filtered.dig("oauth", "state")
    assert_equal "[FILTERED]", filtered.dig("oauth", "nonce")
    assert_equal "[FILTERED]", filtered.dig("oauth", "pkce_verifier")
    assert_equal [ "[FILTERED]" ], filtered.fetch("billing").values.uniq
    assert_equal "[FILTERED]", filtered.dig("api", "api_key")
    assert_equal [ "[FILTERED]" ], filtered.fetch("crawler").values.uniq
    assert_equal "[FILTERED]", filtered.dig("profile", "email")
  end

  test "redacts authorization cookies API keys and webhook signatures in headers" do
    filtered = redaction.headers(
      "Authorization" => "Bearer secret",
      "Cookie" => "session=secret",
      "X-Api-Key" => "api-secret",
      "X-Webhook-Signature" => "signature",
      "Accept" => "application/json"
    )

    assert_equal "application/json", filtered.fetch("Accept")
    assert_equal [ "[FILTERED]" ], filtered.values_at("Authorization", "Cookie", "X-Api-Key", "X-Webhook-Signature").uniq
  end

  test "registers the same sensitive fields with Rails parameter filtering" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    assert_equal "[FILTERED]", filter.filter("oauth_code" => "secret").fetch("oauth_code")
    assert_equal "[FILTERED]", filter.filter("pkce_verifier" => "secret").fetch("pkce_verifier")
    assert_equal "[FILTERED]", filter.filter("X-Api-Key" => "secret").fetch("X-Api-Key")
  end

  test "removes URL credentials fragment and every customer-controlled query value" do
    filtered = redaction.url(
      "https://user:password@example.com/callback?code=oauth-code&scope=read&api_key=secret#access-token"
    )

    assert_equal "https://example.com/callback?code=%5BFILTERED%5D&scope=%5BFILTERED%5D&api_key=%5BFILTERED%5D", filtered
    assert_equal "page=%5BFILTERED%5D&filtered_key=%5BFILTERED%5D", redaction.query("page=2&customer%40email=private")
  end

  test "does not echo an invalid URL" do
    assert_equal "[FILTERED_URL]", redaction.url("https://example.com/%zz?token=secret")
    assert_equal "[FILTERED]", redaction.payload("raw webhook body")
  end

  private

  def redaction
    Rails.application.config.x.redaction
  end
end
