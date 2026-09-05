# frozen_string_literal: true

module Crawling
  module RobotsOctets
    UNRESERVED = /\A[A-Za-z0-9._~-]\z/
    HEX = /\A[0-9A-Fa-f]{2}\z/

    module_function

    def normalize(value)
      input = value.to_s
      raise ArgumentError, "robots path encoding is invalid" unless input.valid_encoding?

      bytes = input.b
      output = +""
      index = 0
      while index < bytes.bytesize
        byte = bytes.getbyte(index)
        if byte == 37
          pair = bytes.byteslice(index + 1, 2)
          raise ArgumentError, "robots percent encoding is invalid" unless pair&.match?(HEX)

          decoded = pair.to_i(16)
          reject_control!(decoded)
          character = decoded.chr
          output << (UNRESERVED.match?(character) ? character : format("%%%02X", decoded))
          index += 3
        else
          reject_control!(byte)
          output << (byte < 128 ? byte.chr : format("%%%02X", byte))
          index += 1
        end
      end
      output.freeze
    end

    def reject_control!(byte)
      raise ArgumentError, "robots control character is invalid" if byte < 32 || byte == 127
    end
    private_class_method :reject_control!
  end
end
