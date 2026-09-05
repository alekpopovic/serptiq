# frozen_string_literal: true

require "test_helper"

class CrawlingRobotsParserTest < ActiveSupport::TestCase
  test "parses the RFC example with exact groups wildcard fallback and empty-group precedence" do
    document = parse_fixture("robots_rfc9309_example.txt")

    assert_equal 4, document.groups.length
    assert_equal %w[barbot bazbot], document.groups.third.agents
    assert_equal 3, document.rules_for("OtherBot").length
    assert_equal 3, document.rules_for("foobot").length
    assert_empty document.rules_for("quxbot")
    assert_empty document.warnings
  end

  test "combines repeated matching groups and applies longest match with allow winning exact ties" do
    document = parse(<<~ROBOTS)
      User-agent: SearchOpsBot
      Disallow: /private
      Allow: /private/public
      Disallow: /tie
      User-agent: searchopsbot
      Allow: /tie
    ROBOTS
    rules = document.rules_for("SearchOpsBot")

    assert_equal 4, rules.length
    assert_winner rules, "/private/report", "disallow", "/private"
    assert_winner rules, "/private/public/report", "allow", "/private/public"
    assert_winner rules, "/tie", "allow", "/tie"
  end

  test "normalizes percent octets and supports RFC wildcard and terminal matching" do
    document = parse_fixture("robots_percent_encoding.txt")
    rules = document.rules_for("SearchOpsBot")

    assert_winner rules, "/foo/bar/baz", "disallow", "/foo/bar/%62%61%7A"
    assert_winner rules, "/foo/bar/baz/public/a", "allow", "/foo/bar/baz/public"
    assert_winner rules, "/unicode/%E3%83%84", "disallow", "/unicode/%E3%83%84"
    assert_winner rules, "/literal/%2A", "disallow", "/literal/%2A"
    assert_winner rules, "/query?view=public", "allow", "/query?view=public$"
    assert_nil winning_rule(rules, "/query?view=public&next=1")
  end

  test "keeps parseable rules around malformed lines and does not let sitemap records terminate groups" do
    document = parse(<<~ROBOTS)
      Disallow: /orphan
      User-agent: SearchOpsBot
      Disallow: /private
      Sitemap: https://cdn.example.com/site.xml
      Bad line
      Allow: /private/public
    ROBOTS

    assert_equal 2, document.rules_for("SearchOpsBot").length
    assert_equal [ "https://cdn.example.com/site.xml" ], document.sitemap_urls
    assert_equal %w[orphan_rule malformed_line], document.warnings.map(&:code)
    refute document.malformed
  end

  test "ignores orphan rules before a later valid group" do
    document = parse(<<~ROBOTS)
      Disallow: /orphan
      User-agent: SearchOpsBot
      Disallow: /private
    ROBOTS

    assert_equal [ "/private" ], document.rules_for("SearchOpsBot").map(&:pattern)
    assert_equal [ "orphan_rule" ], document.warnings.map(&:code)
  end

  test "bounds diagnostics for adversarial malformed input" do
    document = parse(([ "not a directive" ] * 3_000).join("\n"))

    assert_equal Crawling::RobotsParser::MAXIMUM_WARNINGS, document.warnings.length
    assert document.malformed
  end

  test "rejects invalid UTF-8 lines while retaining later parseable policy" do
    body = "invalid: \xFF\nUser-agent: SearchOpsBot\nDisallow: /private\n".b
    document = parse(body)

    assert_equal [ "invalid_utf8" ], document.warnings.map(&:code)
    assert_equal [ "/private" ], document.rules_for("SearchOpsBot").map(&:pattern)
    refute document.malformed
  end

  test "returns only bounded syntactic sitemap candidates and never fetches malicious directives" do
    calls = 0
    normalizer = ->(**attributes) do
      calls += 1
      Crawling::UrlNormalizer.new.call(**attributes)
    end
    document = Crawling::RobotsParser.new(url_normalizer: normalizer).call(body: <<~ROBOTS)
      User-agent: *
      Allow: /
      Sitemap: file:///etc/passwd
      Sitemap: http://169.254.169.254/latest/meta-data
      Sitemap: https://outside.example.net/sitemap.xml
    ROBOTS

    assert_equal 3, calls
    assert_equal [ "https://outside.example.net/sitemap.xml" ], document.sitemap_urls
    assert_equal %w[invalid_sitemap invalid_sitemap], document.warnings.map(&:code)
  end

  test "rejects files beyond the RFC processing limit without parser crashes" do
    body = "User-agent: *\nAllow: /\n".b
    body << ("#" * (Crawling::RobotsParser::MAXIMUM_BYTES - body.bytesize + 1))

    assert_raises(ArgumentError) { parse(body) }
  end

  private

  def parse_fixture(name)
    parse(Rails.root.join("test/fixtures/files/crawling", name).binread)
  end

  def parse(body)
    Crawling::RobotsParser.new.call(body: body)
  end

  def winning_rule(rules, target)
    matches = rules.select { |rule| rule.match?(Crawling::RobotsOctets.normalize(target)) }
    matches.max_by { |rule| [ rule.specificity, rule.allow? ? 1 : 0 ] }
  end

  def assert_winner(rules, target, directive, pattern)
    winner = winning_rule(rules, target)
    assert_equal directive, winner&.directive, target
    assert_equal pattern, winner&.pattern, target
  end
end
