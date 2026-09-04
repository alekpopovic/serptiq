# frozen_string_literal: true

require "test_helper"

class OperationalStatusTest < ActionDispatch::IntegrationTest
  test "up is dependency-free JSON even when readiness dependencies fail" do
    checker = ->(**) { raise "database and provider outage" }
    with_readiness_checker(checker) do
      get up_path
    end

    assert_response :ok
    assert_equal({ "status" => "up" }, response.parsed_body)
    assert_json_and_no_store
  end

  test "ready checks real role-required PostgreSQL connections" do
    get ready_path

    assert_response :ok
    assert_equal({ "status" => "ready", "checks" => { "postgresql" => "ok" } }, response.parsed_body)
    assert_json_and_no_store
  end

  test "ready returns minimal 503 JSON without internal dependency details" do
    failed_check = Shared::OperationalReadiness::Check.new(:queue, false, 1000.0, "unavailable")
    failed_result = Shared::OperationalReadiness::Result.new(:worker_default, [ failed_check ])

    with_readiness_checker(->(**) { failed_result }) do
      get ready_path
    end

    assert_response :service_unavailable
    assert_equal({ "status" => "not_ready", "checks" => { "postgresql" => "unavailable" } },
      response.parsed_body)
    refute_match(/queue|database|latency|hostname|exception|password/, response.body)
    assert_json_and_no_store
  end

  test "version is cache-safe and excludes configuration secrets and host internals" do
    get version_path

    assert_response :ok
    assert_equal "ok", response.parsed_body.fetch("status")
    assert_equal Rails.env, response.parsed_body.fetch("environment")
    assert_equal RUBY_VERSION, response.parsed_body.dig("runtime", "ruby")
    assert_equal Rails.version, response.parsed_body.dig("runtime", "rails")
    assert response.parsed_body.dig("release").key?("build_time")
    refute_match(/database|password|secret|hostname|internal|bucket|token/, response.body)
    assert_json_and_no_store
  end

  private

  def assert_json_and_no_store
    assert_equal "application/json", response.media_type
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_equal "no-cache", response.headers.fetch("Pragma")
    assert_equal "0", response.headers.fetch("Expires")
  end

  def with_readiness_checker(checker)
    previous = OperationalStatusController.readiness_checker
    OperationalStatusController.readiness_checker = checker
    yield
  ensure
    OperationalStatusController.readiness_checker = previous
  end
end
