# frozen_string_literal: true

module Crawling
  class UrlQueryPolicy
    QueryParameter = Data.define(:name, :value, :equals, :position) do
      def render
        equals ? "#{name}=#{value}" : name
      end
    end

    HANDLING_MODES = %w[ignore tracking_only all].freeze
    MAXIMUM_PARAMETERS = 100
    MAXIMUM_QUERY_BYTES = 4096
    MAXIMUM_PARAMETER_NAME_BYTES = 128
    TRACKING_NAMES = %w[
      _ga dclid fbclid gclid mc_cid mc_eid msclkid
    ].freeze
    TRACKING_PREFIXES = %w[utm_ pk_].freeze
    UNRESERVED_BYTES = /\A[A-Za-z0-9._~-]\z/
    QUERY_COMPONENT_BYTES = /\A[A-Za-z0-9._~!$'()*+,;=:@\/?-]\z/
    PERCENT_TRIPLET = /\A[0-9A-Fa-f]{2}\z/

    attr_reader :handling, :allowlist, :denylist

    def initialize(handling:, allowlist: [], denylist: [])
      @handling = handling.to_s
      raise ArgumentError, "query handling is invalid" unless HANDLING_MODES.include?(@handling)

      @allowlist = normalize_filter(allowlist)
      @denylist = normalize_filter(denylist)
      raise ArgumentError, "query parameter filters overlap" if (@allowlist & @denylist).any?
      if @handling == "ignore" && (@allowlist.any? || @denylist.any?)
        raise ArgumentError, "query parameter filters conflict with ignore mode"
      end
      freeze
    end

    def normalize(query)
      parameters = parse(query)
      [ render(parameters), render(identity_parameters(parameters)) ]
    end

    def self.normalize_parameter_name(value)
      raw = value.to_s
      valid = raw.valid_encoding? && raw == raw.strip && raw.bytesize.between?(1, MAXIMUM_PARAMETER_NAME_BYTES) &&
        !raw.include?("&") && !raw.include?("=")
      raise ArgumentError, "query parameter name is invalid" unless valid

      normalize_component(raw)
    end

    def self.normalize_component(value)
      input = value.to_s
      raise ArgumentError, "query component is invalid" unless input.valid_encoding?

      bytes = input.b
      output = +""
      index = 0
      while index < bytes.bytesize
        byte = bytes.getbyte(index)
        if byte == 37
          pair = bytes.byteslice(index + 1, 2)
          raise ArgumentError, "query percent encoding is invalid" unless
            pair&.bytesize == 2 && PERCENT_TRIPLET.match?(pair)

          decoded = pair.to_i(16)
          reject_control_byte!(decoded)
          character = decoded.chr
          output << (UNRESERVED_BYTES.match?(character) ? character : format("%%%02X", decoded))
          index += 3
          next
        end

        reject_control_byte!(byte)
        character = byte.chr
        output << (byte < 128 && QUERY_COMPONENT_BYTES.match?(character) ? character : format("%%%02X", byte))
        index += 1
      end
      output.freeze
    end

    def self.reject_control_byte!(byte)
      raise ArgumentError, "encoded control characters are forbidden" if byte < 32 || byte == 127
    end
    private_class_method :reject_control_byte!

    private

    def parse(query)
      return [] if query.nil? || query.empty?

      raw = query.to_s
      raise ArgumentError, "query is too long" if raw.bytesize > MAXIMUM_QUERY_BYTES

      parts = raw.split("&", -1)
      raise ArgumentError, "query has too many parameters" if parts.length > MAXIMUM_PARAMETERS

      parts.each_with_index.map do |part, position|
        name, separator, value = part.partition("=")
        QueryParameter.new(
          name: self.class.normalize_component(name),
          value: self.class.normalize_component(value),
          equals: separator == "=",
          position: position
        )
      end
    end

    def identity_parameters(parameters)
      return [] if handling == "ignore"

      parameters.select { |parameter| retained?(parameter.name) }
        .sort_by { |parameter| [ parameter.name, parameter.position ] }
    end

    def retained?(name)
      return false if denylist.include?(name)
      return false if allowlist.any? && !allowlist.include?(name)
      return false if handling == "tracking_only" && tracking?(name)

      true
    end

    def tracking?(name)
      comparable = name.downcase
      TRACKING_NAMES.include?(comparable) || TRACKING_PREFIXES.any? { |prefix| comparable.start_with?(prefix) }
    end

    def render(parameters)
      parameters.map(&:render).join("&").presence
    end

    def normalize_filter(values)
      Array(values).map { |value| self.class.normalize_parameter_name(value) }.uniq.sort.freeze
    end
  end
end
