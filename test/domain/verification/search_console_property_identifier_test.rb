# frozen_string_literal: true

require "test_helper"

class SearchConsolePropertyIdentifierTest < ActiveSupport::TestCase
  test "URL-prefix properties require the exact normalized root origin" do
    prefix = Verification::SearchConsolePropertyIdentifier.parse("https://example.com/")

    assert_equal "url_prefix", prefix.property_type
    assert prefix.matches_origin?("https://example.com")
    refute prefix.matches_origin?("http://example.com")
    refute prefix.matches_origin?("https://www.example.com")
    assert_raises(ArgumentError) do
      Verification::SearchConsolePropertyIdentifier.parse("https://example.com/docs/")
    end
  end

  test "domain properties cover only the same canonical host" do
    domain = Verification::SearchConsolePropertyIdentifier.parse("sc-domain:example.com")

    assert_equal "domain", domain.property_type
    assert domain.matches_origin?("http://example.com")
    assert domain.matches_origin?("https://example.com")
    refute domain.matches_origin?("https://www.example.com")
    refute domain.matches_origin?("https://sibling.example.com")
    refute domain.matches_origin?("https://notexample.com")
  end

  test "rejects noncanonical and ambiguous provider identifiers" do
    %w[sc-domain:Example.com sc-domain:127.0.0.1 https://example.com https://user@example.com/].each do |value|
      assert_raises(ArgumentError, value) do
        Verification::SearchConsolePropertyIdentifier.parse(value)
      end
    end
  end
end
