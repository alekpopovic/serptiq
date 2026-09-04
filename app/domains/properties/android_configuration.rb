# frozen_string_literal: true

module Properties
  AndroidConfiguration = Data.define(:package_name) do
    PATTERN = /\A[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+\z/

    def initialize(package_name:)
      normalized = package_name.to_s.strip.downcase
      raise ArgumentError, "Android package name is invalid" unless PATTERN.match?(normalized)

      super(package_name: normalized.freeze)
      freeze
    end

    def identifier
      package_name
    end

    def database_attributes
      { package_name: package_name }
    end
  end
end
