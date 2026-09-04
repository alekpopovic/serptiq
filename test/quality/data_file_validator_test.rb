# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require Rails.root.join("script/support/data_file_validator")

class DataFileValidatorTest < ActiveSupport::TestCase
  test "accepts YAML with ERB and valid JSON" do
    with_files(
      "config/example.yml" => "value: <%= 2 + 2 %>\n",
      "schemas/example.json" => %({"type":"object"}\n)
    ) do |root|
      validator = Searchops::Quality::DataFileValidator.new(root: root)

      assert_empty validator.validate
      assert_equal 2, validator.files.count
    end
  end

  test "reports malformed JSON and YAML without stopping at the first file" do
    with_files(
      "bad.json" => %({"missing": }\n),
      "bad.yml" => "items: [one, two\n"
    ) do |root|
      errors = Searchops::Quality::DataFileValidator.new(root: root).validate

      assert_equal 2, errors.count
      assert errors.any? { |error| error.include?("bad.json: invalid JSON") }
      assert errors.any? { |error| error.include?("bad.yml: invalid YAML/ERB") }
    end
  end

  test "rejects duplicate YAML keys" do
    with_files("duplicate.yml" => "plan:\n  key: free\n  key: paid\n") do |root|
      errors = Searchops::Quality::DataFileValidator.new(root: root).validate

      assert_equal [ %(duplicate.yml: duplicate YAML key "plan.key") ], errors
    end
  end

  test "rejects duplicate JSON keys" do
    with_files("duplicate.json" => %({"plan":"free","plan":"paid"}\n)) do |root|
      errors = Searchops::Quality::DataFileValidator.new(root: root).validate

      assert_equal [ %(duplicate.json: invalid JSON: duplicate key "plan" at line 1 column 1) ], errors
    end
  end

  test "does not scan generated or vendored trees" do
    with_files(
      "config/valid.yml" => "valid: true\n",
      "public/assets/bad.json" => "not json",
      "vendor/bad.yml" => ":"
    ) do |root|
      validator = Searchops::Quality::DataFileValidator.new(root: root)

      assert_empty validator.validate
      assert_equal [ "config/valid.yml" ], validator.files.map { |path| path.relative_path_from(root).to_s }
    end
  end

  private

  def with_files(files)
    Dir.mktmpdir("searchops-data-validator") do |directory|
      root = Pathname(directory)
      files.each do |relative, contents|
        path = root.join(relative)
        path.dirname.mkpath
        path.write(contents)
      end
      yield root
    end
  end
end
