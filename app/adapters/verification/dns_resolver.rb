# frozen_string_literal: true

require "resolv"
require "timeout"

module Verification
  class DnsResolver
    class ResolvQuery
      def call(name:, timeout:)
        dns = Resolv::DNS.new
        dns.timeouts = timeout
        response = nil
        Timeout.timeout(timeout) do
          absolute_name = Resolv::DNS::Name.create("#{name}.")
          dns.fetch_resource(absolute_name, Resolv::DNS::Resource::IN::TXT) do |reply, reply_name|
            response = {
              question_name: reply_name.to_s,
              answer_count: reply.answer.length,
              delegation_count: reply.authority.count do |_owner, _ttl, resource|
                resource.is_a?(Resolv::DNS::Resource::IN::NS)
              end,
              records: reply.answer.filter_map { |answer| record_from(answer) }
            }
          end
        end
        response || raise(Resolv::ResolvError, "resolver returned no response")
      ensure
        dns&.close
      end

      private

      def record_from(answer)
        owner, _ttl, resource = answer
        case resource
        when Resolv::DNS::Resource::IN::TXT
          { type: "txt", name: owner.to_s, strings: resource.strings.map(&:to_s) }
        when Resolv::DNS::Resource::IN::CNAME
          { type: "cname", name: owner.to_s, target: resource.name.to_s }
        end
      end
    end

    DEFAULTS = {
      timeout: 3.seconds,
      max_records: 32,
      max_response_bytes: 4096,
      max_cname_hops: 5,
      max_delegations: 8
    }.freeze

    def initialize(query: ResolvQuery.new, **limits)
      @query = query
      @timeout = Float(limits.fetch(:timeout, DEFAULTS.fetch(:timeout)))
      @max_records = Integer(limits.fetch(:max_records, DEFAULTS.fetch(:max_records)))
      @max_response_bytes = Integer(
        limits.fetch(:max_response_bytes, DEFAULTS.fetch(:max_response_bytes))
      )
      @max_cname_hops = Integer(limits.fetch(:max_cname_hops, DEFAULTS.fetch(:max_cname_hops)))
      @max_delegations = Integer(limits.fetch(:max_delegations, DEFAULTS.fetch(:max_delegations)))
      validate_limits!
    end

    def resolve(name:)
      intended_name = normalize_name(name)
      response = @query.call(name: intended_name, timeout: @timeout)
      question_name = normalize_name(response.fetch(:question_name))
      return resolution("malformed_response", question_match: false) unless question_name == intended_name

      answer_count = Integer(response.fetch(:answer_count))
      delegation_count = Integer(response.fetch(:delegation_count, 0))
      return resolution("response_limit", record_count: answer_count,
        delegation_count: delegation_count) if answer_count > @max_records
      return resolution("delegation_limit", record_count: answer_count,
        delegation_count: delegation_count) if delegation_count > @max_delegations

      records = Array(response.fetch(:records))
      return resolution("response_limit", record_count: answer_count,
        delegation_count: delegation_count) if response_bytes(records) > @max_response_bytes

      extract_txt(
        intended_name: intended_name,
        records: records,
        answer_count: answer_count,
        delegation_count: delegation_count
      )
    rescue Resolv::DNS::Config::NXDomain
      resolution("nxdomain")
    rescue Resolv::ResolvTimeout, Timeout::Error
      resolution("timeout")
    rescue KeyError, TypeError, ArgumentError
      resolution("malformed_response")
    rescue Resolv::ResolvError, SocketError, IOError, SystemCallError
      resolution("transient_failure")
    end

    private

    def extract_txt(intended_name:, records:, answer_count:, delegation_count:)
      normalized = records.map { |record| normalize_record(record) }
      current_name = intended_name
      visited = { current_name => true }
      cname_hops = 0

      loop do
        txt_records = normalized.select { |record| record[:type] == "txt" && record[:name] == current_name }
        if txt_records.any?
          values = txt_records.map { |record| record.fetch(:strings).join.b }
          return resolution(
            "resolved", records: values, record_count: values.length, cname_hops: cname_hops,
            delegation_count: delegation_count
          )
        end

        aliases = normalized.select { |record| record[:type] == "cname" && record[:name] == current_name }
        return resolution("no_record", record_count: answer_count, cname_hops: cname_hops,
          delegation_count: delegation_count) if aliases.empty?
        return resolution("malformed_response", record_count: answer_count, cname_hops: cname_hops,
          delegation_count: delegation_count) unless aliases.one?

        cname_hops += 1
        return resolution("cname_limit", record_count: answer_count, cname_hops: cname_hops,
          delegation_count: delegation_count) if cname_hops > @max_cname_hops

        current_name = aliases.sole.fetch(:target)
        return resolution("cname_limit", record_count: answer_count, cname_hops: cname_hops,
          delegation_count: delegation_count) if visited[current_name]

        visited[current_name] = true
      end
    end

    def normalize_record(record)
      source = record.to_h.transform_keys(&:to_sym)
      type = source.fetch(:type).to_s
      name = normalize_name(source.fetch(:name))
      case type
      when "txt"
        strings = Array(source.fetch(:strings)).map { |chunk| chunk.to_s.b }
        raise ArgumentError, "empty TXT record" if strings.empty?

        { type: type, name: name, strings: strings }
      when "cname"
        { type: type, name: name, target: normalize_name(source.fetch(:target)) }
      else
        raise ArgumentError, "unexpected DNS record type"
      end
    end

    def normalize_name(value)
      name = value.to_s.downcase.delete_suffix(".")
      labels = name.split(".")
      valid = name.bytesize.between?(1, 253) && labels.all? do |label|
        label.bytesize.between?(1, 63) && label.match?(/\A[a-z0-9_](?:[a-z0-9_-]*[a-z0-9_])?\z/)
      end
      raise ArgumentError, "invalid DNS name" unless valid

      name.freeze
    end

    def response_bytes(records)
      records.sum do |record|
        source = record.to_h
        source.values.flatten.sum { |value| value.to_s.b.bytesize }
      end
    end

    def resolution(status, **attributes)
      DnsResolution.new(status: status, **attributes)
    end

    def validate_limits!
      raise ArgumentError, "DNS timeout is out of range" unless @timeout.between?(0.1, 10.0)
      raise ArgumentError, "DNS record limit is out of range" unless @max_records.between?(1, 100)
      unless @max_response_bytes.between?(256, 65_536)
        raise ArgumentError, "DNS response limit is out of range"
      end
      raise ArgumentError, "DNS CNAME limit is out of range" unless @max_cname_hops.between?(0, 10)
      raise ArgumentError, "DNS delegation limit is out of range" unless @max_delegations.between?(0, 32)
    end
  end
end
