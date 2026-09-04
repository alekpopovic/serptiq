# frozen_string_literal: true

require "test_helper"

class VerificationDnsResolverTest < ActiveSupport::TestCase
  FakeQuery = Struct.new(:response, :error, :calls, keyword_init: true) do
    def call(name:, timeout:)
      calls << { name: name, timeout: timeout }
      raise error if error

      response
    end
  end

  test "resolves only the exact question and concatenates TXT chunks without normalization" do
    query = fake_query(response(
      records: [ txt(dns_name, [ "searchops-verification=abc", "DEF " ]) ]
    ))

    result = resolver(query: query).resolve(name: dns_name)

    assert result.resolved?
    assert_equal [ "searchops-verification=abcDEF " ], result.records
    assert_equal [ { name: dns_name, timeout: 1.5 } ], query.calls
    assert_equal 1, result.record_count
  end

  test "classifies NXDOMAIN timeout and empty answers distinctly" do
    nxdomain = fake_query(nil, Resolv::DNS::Config::NXDomain.new(dns_name))
    timeout = fake_query(nil, Resolv::ResolvTimeout.new(dns_name))
    empty = fake_query(response)

    assert_equal "nxdomain", resolver(query: nxdomain).resolve(name: dns_name).status
    assert_equal "timeout", resolver(query: timeout).resolve(name: dns_name).status
    assert_equal "no_record", resolver(query: empty).resolve(name: dns_name).status
  end

  test "returns multiple TXT records without exposing unrelated answer types" do
    query = fake_query(response(
      answer_count: 3,
      records: [
        txt(dns_name, [ "one" ]),
        { type: "cname", name: "unrelated.example", target: "elsewhere.example" },
        txt(dns_name, [ "two" ])
      ]
    ))

    result = resolver(query: query).resolve(name: dns_name)

    assert result.resolved?
    assert_equal [ "one", "two" ], result.records
    assert_equal 2, result.record_count
    assert result.evidence.fetch(:multiple_records)
  end

  test "follows only a bounded CNAME chain already present in the intended response" do
    target = "proof.example.net"
    query = fake_query(response(
      answer_count: 2,
      records: [
        { type: "cname", name: dns_name, target: target },
        txt(target, [ "proof" ])
      ]
    ))

    result = resolver(query: query).resolve(name: dns_name)

    assert_equal "resolved", result.status
    assert_equal [ "proof" ], result.records
    assert_equal 1, result.cname_hops
    assert_equal 1, query.calls.length
  end

  test "rejects question reuse and bounded response CNAME and delegation excess" do
    wrong_question = fake_query(response(question_name: "other.example"))
    too_many_records = fake_query(response(answer_count: 4))
    too_many_delegations = fake_query(response(delegation_count: 3))
    cname_loop = fake_query(response(
      answer_count: 1,
      records: [ { type: "cname", name: dns_name, target: dns_name } ]
    ))

    assert_equal "malformed_response", resolver(query: wrong_question).resolve(name: dns_name).status
    assert_equal "response_limit",
      resolver(query: too_many_records, max_records: 3).resolve(name: dns_name).status
    assert_equal "delegation_limit",
      resolver(query: too_many_delegations, max_delegations: 2).resolve(name: dns_name).status
    assert_equal "cname_limit", resolver(query: cname_loop).resolve(name: dns_name).status
  end

  test "caps retained TXT bytes before returning any values" do
    query = fake_query(response(records: [ txt(dns_name, [ "x" * 300 ]) ]))

    result = resolver(query: query, max_response_bytes: 256).resolve(name: dns_name)

    assert_equal "response_limit", result.status
    assert_empty result.records
  end

  private

  def dns_name
    "_searchops-verification.example.com"
  end

  def fake_query(value, error = nil)
    FakeQuery.new(response: value, error: error, calls: [])
  end

  def resolver(query:, **limits)
    Verification::DnsResolver.new(query: query, timeout: 1.5, **limits)
  end

  def response(question_name: dns_name, answer_count: 0, delegation_count: 0, records: [])
    {
      question_name: question_name,
      answer_count: answer_count.zero? ? records.length : answer_count,
      delegation_count: delegation_count,
      records: records
    }
  end

  def txt(owner, strings)
    { type: "txt", name: owner, strings: strings }
  end
end
