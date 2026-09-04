# frozen_string_literal: true

module Projects
  module ProjectSlug
    module_function

    def call(value)
      ActiveSupport::Inflector.transliterate(value.to_s)
        .downcase
        .strip
        .gsub(/[^a-z0-9]+/, "-")
        .gsub(/\A-+|-+\z/, "")
        .first(63)
        .to_s
        .gsub(/-+\z/, "")
    end
  end
end
