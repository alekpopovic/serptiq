# frozen_string_literal: true

module Verification
  SearchConsoleOption = Data.define(
    :selection_token, :external_property_identifier, :property_type, :permission_level
  ) do
    def initialize(**attributes)
      attributes.each_key { |name| attributes[name] = attributes.fetch(name).to_s.freeze }
      super(**attributes)
      freeze
    end

    def label
      "#{external_property_identifier} (verified owner)"
    end
  end
end
