# frozen_string_literal: true

require "test_helper"

class CrawlerInformationRequestTest < ActionDispatch::IntegrationTest
  test "public crawler page identifies SearchOpsBot and explains the robots trust boundary" do
    get crawler_information_path

    assert_response :success
    assert_select "h1", text: "About SearchOpsBot"
    assert_includes response.body, "SearchOpsBot/1.0 (+https://searchops.test/crawler)"
    assert_includes response.body, "robots.txt is not access control"
    assert_includes response.body, "never bypasses destination validation"
  end
end
