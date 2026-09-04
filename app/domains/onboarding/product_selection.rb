# frozen_string_literal: true

module Onboarding
  ProductSelection = Data.define(:flow_type, :add_android, :add_ios) do
    def initialize(flow_type:, add_android:, add_ios:)
      flow = flow_type.to_s
      errors = {}
      android = boolean(add_android, :add_android, errors)
      ios = boolean(add_ios, :add_ios, errors)
      errors[:flow_type] = "Choose website-only or combined web and mobile setup." unless
        Draft::FLOW_TYPES.include?(flow)
      if flow == "website_only"
        android = false
        ios = false
      elsif flow == "combined" && !android && !ios
        errors[:mobile_platforms] = "Choose Android, iOS, or both for a combined setup."
      end
      raise Invalid.new(field_errors: errors) if errors.any?

      super(flow_type: flow.freeze, add_android: android, add_ios: ios)
      freeze
    end

    private

    def boolean(value, field, errors)
      return true if value == true || value == 1 || value == "1"
      return false if value.nil? || value == false || value == 0 || value == "0"

      errors[field] = "Choose a valid yes or no value."
      false
    end
  end
end
