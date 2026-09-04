# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require Rails.root.join("script/support/ci_workflow_validator")

class CiWorkflowValidatorTest < ActiveSupport::TestCase
  test "accepts the repository CI workflow" do
    validator = Searchops::Quality::CiWorkflowValidator.new(path: Rails.root.join(".github/workflows/ci.yml"))

    assert_empty validator.validate
  end

  test "rejects mutable actions and write permissions" do
    source = Rails.root.join(".github/workflows/ci.yml").read
      .sub("actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1", "actions/checkout@main")
      .sub("contents: read", "contents: write")
      .sub("persist-credentials: false", "persist-credentials: true")

    with_workflow(source) do |path|
      errors = Searchops::Quality::CiWorkflowValidator.new(path: path).validate

      assert errors.any? { |error| error.include?("top-level permissions") }
      assert errors.any? { |error| error.include?("not pinned to a full commit SHA") }
      assert errors.any? { |error| error.include?("credential persistence") }
    end
  end

  test "rejects durable success artifacts and unpinned service images" do
    source = Rails.root.join(".github/workflows/ci.yml").read
      .sub("if: failure()", "if: always()")
      .sub("retention-days: 3", "retention-days: 30")
      .sub(/postgres:17-alpine@sha256:[0-9a-f]{64}/, "postgres:17-alpine")

    with_workflow(source) do |path|
      errors = Searchops::Quality::CiWorkflowValidator.new(path: path).validate

      assert errors.any? { |error| error.include?("failure-only") }
      assert errors.any? { |error| error.include?("pin PostgreSQL") }
    end
  end

  test "rejects secrets and unconditional protected-branch cancellation" do
    source = Rails.root.join(".github/workflows/ci.yml").read
      .sub(/cancel-in-progress: .+/, "cancel-in-progress: true")
      .sub("RAILS_ENV: test", "RAILS_ENV: ${{ secrets.PRODUCTION_KEY }}")

    with_workflow(source) do |path|
      errors = Searchops::Quality::CiWorkflowValidator.new(path: path).validate

      assert errors.any? { |error| error.include?("default-branch") }
      assert errors.any? { |error| error.include?("repository secrets") }
    end
  end

  private

  def with_workflow(source)
    Dir.mktmpdir("searchops-ci-workflow") do |directory|
      root = Pathname(directory)
      path = root.join(".github/workflows/ci.yml")
      path.dirname.mkpath
      path.write(source)
      root.join("Gemfile.lock").write(Rails.root.join("Gemfile.lock").read)
      yield path
    end
  end
end
