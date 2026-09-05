# frozen_string_literal: true

require "test_helper"
require Rails.root.join("script/support/authorization_coverage_checker")

class AuthorizationCoverageCheckerTest < ActiveSupport::TestCase
  test "all tenant controllers jobs and mapped operations have governed policies" do
    issues = Searchops::Authorization::CoverageChecker.new(
      root: Rails.root,
      inventory_path: Rails.root.join("config/authorization_inventory.yml")
    ).check

    assert_empty issues, issues.join("\n")
  end

  test "rejects missing and permission-incompatible resource scope metadata" do
    issues = with_inventory do |document|
      actions = document.fetch("controllers").fetch("Projects::ProjectsController").fetch("actions")
      actions.fetch("show").delete("scope")
      actions.fetch("new")["scope"] = "property"
    end

    assert_includes issues,
      "Projects::ProjectsController#show: scoped resource action is missing scope metadata"
    assert_includes issues,
      "Projects::ProjectsController#new: projects.create is incompatible with property scope"
  end

  test "rejects unbounded filtered collection declarations" do
    issues = with_inventory do |document|
      policy = document.fetch("controllers").fetch("Properties::PropertiesController")
        .fetch("actions").fetch("index")
      policy["scope"] = "property"
      policy.delete("reason")
    end

    assert_includes issues,
      "Properties::PropertiesController#index: filtered collection requires a reason"
    assert_includes issues,
      "Properties::PropertiesController#index: filtered collection has incompatible scope property"
  end

  private

  def with_inventory
    document = YAML.safe_load_file(
      Rails.root.join("config/authorization_inventory.yml"), aliases: true
    )
    yield document
    directory = Pathname(Dir.mktmpdir("authorization-inventory"))
    path = directory.join("inventory.yml")
    path.write(YAML.dump(document))
    Searchops::Authorization::CoverageChecker.new(root: Rails.root, inventory_path: path).check
  ensure
    FileUtils.remove_entry(directory) if directory&.exist?
  end
end
