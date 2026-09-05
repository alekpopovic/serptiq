# frozen_string_literal: true

require "test_helper"

class CrawlingGlobPatternTest < ActiveSupport::TestCase
  test "compiles bounded path globs with explicit segment semantics" do
    segment = Crawling::Public.compile_glob("/products/*")
    recursive = Crawling::Public.compile_glob("/docs/**")

    assert segment.match?("/products/widget")
    refute segment.match?("/products/group/widget")
    assert recursive.match?("/docs/group/page")
    refute recursive.match?("/other/docs/page")
    literal = Crawling::Public.compile_glob("/__SEARCHOPS_RECURSIVE_GLOB__")
    assert literal.match?("/__SEARCHOPS_RECURSIVE_GLOB__")
    refute literal.match?("/anything")
  end

  test "rejects regex syntax excessive length and excessive wildcard complexity" do
    unsafe = [
      "/(a+)+$",
      "/[a-z]+",
      "/#{'a' * 256}",
      "/#{Array.new(13, '*').join('/')} ".strip,
      "/**/**/**/**/**",
      "relative/**"
    ]

    unsafe.each do |pattern|
      assert_raises(ArgumentError, pattern) { Crawling::Public.compile_glob(pattern) }
    end
  end
end
