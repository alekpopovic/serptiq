# frozen_string_literal: true

require "test_helper"

class VerificationFactoryTest < ActiveSupport::TestCase
  test "wires both HTTP methods to the centralized safe client when enabled" do
    registry = VerificationFactory.adapter_registry(settings: {
      dns_verification_enabled: false,
      http_verification_enabled: true,
      search_console_enabled: false,
      verification_http_dns_timeout: 1,
      verification_http_open_timeout: 1,
      verification_http_read_timeout: 1,
      verification_http_max_response_bytes: 4096,
      verification_http_max_redirects: 1
    })

    assert_instance_of Verification::Adapters::HtmlFile, registry.fetch("html_file")
    assert_instance_of Verification::Adapters::MetaTag, registry.fetch("meta_tag")
    assert_instance_of Verification::Adapters::Unconfigured, registry.fetch("search_console")
  end

  test "keeps HTTP methods unavailable when outbound verification is disabled" do
    registry = VerificationFactory.adapter_registry(settings: {
      dns_verification_enabled: false,
      http_verification_enabled: false,
      search_console_enabled: false
    })

    assert_instance_of Verification::Adapters::Unconfigured, registry.fetch("html_file")
    assert_instance_of Verification::Adapters::Unconfigured, registry.fetch("meta_tag")
  end

  test "wires the Search Console verification adapter only when enabled" do
    registry = VerificationFactory.adapter_registry(settings: {
      dns_verification_enabled: false,
      http_verification_enabled: false,
      search_console_enabled: true
    })

    assert_instance_of Verification::Adapters::SearchConsole, registry.fetch("search_console")
  end
end
