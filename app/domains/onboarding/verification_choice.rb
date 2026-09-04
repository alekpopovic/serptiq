# frozen_string_literal: true

module Onboarding
  VerificationChoice = Data.define(:method) do
    def initialize(method:)
      value = method.to_s
      unless Draft::VERIFICATION_METHODS.include?(value)
        raise Invalid.new(field_errors: { verification_method: "Choose an ownership verification method." })
      end

      super(method: value.freeze)
      freeze
    end
  end
end
