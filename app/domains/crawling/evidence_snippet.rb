# frozen_string_literal: true

module Crawling
  class EvidenceSnippet
    CONTROL_CHARACTERS = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/

    def self.call(value, maximum_bytes:)
      text = value.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "�")
        .gsub(CONTROL_CHARACTERS, " ").gsub(/\s+/, " ").strip
      return text.freeze if text.bytesize <= maximum_bytes

      truncated = text.byteslice(0, maximum_bytes).to_s.scrub("")
      truncated = truncated.byteslice(0, truncated.bytesize - 1).to_s.scrub("") while
        truncated.bytesize > maximum_bytes
      truncated.rstrip.freeze
    end
  end
end
