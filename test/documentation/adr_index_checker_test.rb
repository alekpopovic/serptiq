# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require Rails.root.join("script/support/adr_index_checker")

class AdrIndexCheckerTest < ActiveSupport::TestCase
  test "repository ADR index and metadata are consistent" do
    errors = checker(Rails.root.join("docs/adr")).errors

    assert_empty errors, errors.join("\n")
  end

  test "reports an indexed link that does not resolve" do
    Dir.mktmpdir("searchops-adr-index") do |directory|
      File.write(Pathname(directory).join("README.md"), "[0001 — Missing](./0001_missing.md)\n")
      File.write(Pathname(directory).join("ADR_TEMPLATE.md"), template)

      errors = checker(directory).errors

      assert_includes errors, "ADR 0001 link does not resolve: ./0001_missing.md"
      assert_includes errors, "index references unknown ADRs: 0001"
    end
  end

  private

  def checker(directory)
    Searchops::Documentation::AdrIndexChecker.new(directory: directory)
  end

  def template
    Searchops::Documentation::AdrIndexChecker::REQUIRED_TEMPLATE_HEADINGS
      .map { |heading| "## #{heading}\n" }
      .join + <<~METADATA
        - Owners: owner
        - Reviewers: reviewer
        - Last reviewed: 2026-09-04
        - Supersedes: None
        - Superseded by: None
      METADATA
  end
end
