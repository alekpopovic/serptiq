# frozen_string_literal: true

module Crawling
  module ArtifactFilename
    MAX_BYTES = 160
    module_function

    def sanitize(value, fallback: "artifact.bin")
      basename = File.basename(value.to_s.tr("\\", "/"))
      sanitized = basename.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
        .gsub(/[^A-Za-z0-9._-]+/, "-").gsub(/\A[.-]+|[.-]+\z/, "")
      sanitized = fallback unless sanitized.present?
      sanitized.byteslice(0, MAX_BYTES).to_s.sub(/[.-]+\z/, "").presence || fallback
    end

    def content_disposition(filename)
      %(attachment; filename="#{sanitize(filename).gsub(/["\\]/, "-")}")
    end
  end
end
