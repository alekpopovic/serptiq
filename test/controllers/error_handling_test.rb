# frozen_string_literal: true

require "test_helper"
require "json"

class ErrorHandlingTestController < ApplicationController
  def quota
    raise Shared::Errors::QuotaError.new("secret operator detail", reason_code: "monthly_credit_limit")
  end

  def unexpected
    cause = IOError.new("provider token private-value")
    raise RuntimeError.new("database password private-value"), cause: cause
  end
end

class ErrorHandlingTest < ActionController::TestCase
  tests ErrorHandlingTestController

  class CaptureLogger
    attr_reader :entries

    def initialize
      @entries = []
    end

    %i[debug info warn error fatal].each do |severity|
      define_method(severity) { |message| entries << [ severity, message ] }
    end
  end

  class CaptureErrorSubscriber
    attr_reader :reports

    def initialize
      @reports = []
    end

    def report(error, **details)
      reports << [ error, details ]
    end
  end

  setup do
    @previous_emitter = Shared::Observability.emitter
    @logger = CaptureLogger.new
    @error_subscriber = CaptureErrorSubscriber.new
    Rails.error.subscribe(@error_subscriber)
    Shared::Observability.emitter = Shared::Observability::EventEmitter.new(logger: @logger)
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw do
      get "quota", to: "error_handling_test#quota"
      get "unexpected", to: "error_handling_test#unexpected"
    end
  end

  teardown do
    Rails.error.unsubscribe(@error_subscriber)
    Shared::Observability.emitter = @previous_emitter
    Shared::Observability::Context.reset
  end

  test "maps an expected domain error to a stable JSON response" do
    get :quota, format: :json

    assert_response :too_many_requests
    assert_equal "quota_exceeded", response.headers.fetch("X-SearchOps-Error-Code")
    error = JSON.parse(response.body).fetch("error")
    assert_equal "quota_exceeded", error.fetch("code")
    assert_equal "The available usage limit has been reached.", error.fetch("message")
    refute_match(/secret operator detail/, response.body)

    event = JSON.parse(@logger.entries.last.last)
    assert_equal "quota", event.fetch("error_category")
    assert_equal "monthly_credit_limit", event.fetch("reason_code")
    assert_empty @error_subscriber.reports
  end

  test "maps an unexpected fault without exposing its message or cause" do
    get :unexpected, format: :json

    assert_response :internal_server_error
    assert_equal "internal_error", response.headers.fetch("X-SearchOps-Error-Code")
    assert_equal "internal_error", JSON.parse(response.body).dig("error", "code")
    refute_match(/database password|provider token|private-value/, response.body)

    event = JSON.parse(@logger.entries.last.last)
    assert_equal "RuntimeError", event.fetch("exception_class")
    assert_equal [ "IOError" ], event.fetch("cause_classes")
    refute_match(/private-value/, JSON.generate(event))

    reported_error, details = @error_subscriber.reports.fetch(0)
    assert_instance_of RuntimeError, reported_error
    assert_instance_of IOError, reported_error.cause
    assert_equal "internal_error", details.dig(:context, "public_error_code")
    assert_equal :error, details.fetch(:severity)
  end

  test "renders the same stable code and message for HTML" do
    get :quota

    assert_response :too_many_requests
    assert_select "#public-error-title", /could not complete/i
    assert_select "p", /Error code: quota_exceeded/
    refute_match(/secret operator detail/, response.body)
  end
end
