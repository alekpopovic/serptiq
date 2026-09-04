# frozen_string_literal: true

module Onboarding
  Completion = Data.define(
    :draft, :project, :website_property, :android_property, :ios_property, :challenge
  ) do
    def initialize(**attributes)
      super(**attributes)
      freeze
    end
  end
end
