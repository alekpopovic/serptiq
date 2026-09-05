# frozen_string_literal: true

require "resolv"
require "socket"

module TestSupport
  module Network
    class MaliciousDnsFixture
      HOST = "127.0.0.1"
      MAX_PACKET_BYTES = 4096
      RESOURCE_TYPES = {
        a: Resolv::DNS::Resource::IN::A,
        aaaa: Resolv::DNS::Resource::IN::AAAA
      }.freeze

      attr_reader :host, :port, :requests

      def initialize
        @host = HOST
        @scripts = {}
        @indexes = Hash.new(0)
        @requests = Queue.new
        @mutex = Mutex.new
      end

      def script(host:, type:, responses:)
        raise "fixture is already running" if @socket

        key = key_for(host, type)
        sequence = Array(responses).map { |answer_set| Array(answer_set).map(&:to_s).freeze }.freeze
        raise ArgumentError, "DNS response script is empty" if sequence.empty?

        @scripts[key] = sequence
        self
      end

      def start
        @socket = UDPSocket.new(Socket::AF_INET)
        @socket.bind(HOST, 0)
        @port = @socket.local_address.ip_port
        @thread = Thread.new { serve }
        self
      end

      def stop
        @socket&.close
        @thread&.join(1)
        @thread = nil
        @socket = nil
      end

      def resolver(timeout: 1)
        Shared::NetworkSafety::PublicResolver.new(
          timeout: timeout,
          dns_factory: -> {
            Resolv::DNS.new(
              nameserver_port: [ [ HOST, port ] ],
              search: [],
              ndots: 1
            )
          }
        )
      end

      private

      def serve
        loop do
          packet, sender = @socket.recvfrom(MAX_PACKET_BYTES)
          handle(packet, sender)
        end
      rescue IOError, Errno::EBADF
        nil
      end

      def handle(packet, sender)
        query = Resolv::DNS::Message.decode(packet)
        response = Resolv::DNS::Message.new(query.id)
        response.qr = 1
        response.opcode = query.opcode
        response.aa = 1
        response.rd = query.rd
        query.each_question do |name, resource_type|
          response.add_question(name, resource_type)
          add_answers(response, name, resource_type)
        end
        @socket.send(response.encode, 0, sender.fetch(3), sender.fetch(1))
      rescue Resolv::DNS::DecodeError
        nil
      end

      def add_answers(message, name, resource_type)
        type = RESOURCE_TYPES.key(resource_type)
        return unless type

        normalized_host = name.to_s.delete_suffix(".").downcase
        requests << { host: normalized_host, type: type }.freeze
        answers_for(normalized_host, type).each do |address|
          resource = resource_type.new(address)
          message.add_answer(name, 0, resource)
        end
      end

      def answers_for(host, type)
        key = [ host, type ]
        @mutex.synchronize do
          script = @scripts.fetch(key, [ [] ])
          index = @indexes[key]
          @indexes[key] += 1
          script.fetch([ index, script.length - 1 ].min)
        end
      end

      def key_for(host, type)
        normalized_type = type.to_sym
        raise ArgumentError, "unsupported DNS resource type" unless RESOURCE_TYPES.key?(normalized_type)

        [ host.to_s.delete_suffix(".").downcase, normalized_type ]
      end
    end
  end
end
