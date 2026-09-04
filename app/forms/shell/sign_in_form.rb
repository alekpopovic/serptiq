# frozen_string_literal: true

module Shell
  class SignInForm
    include ActiveModel::Model
    include ActiveModel::Attributes

    PROVIDERS = %w[google github].freeze

    attribute :provider, :string

    validates :provider, inclusion: {
      in: PROVIDERS,
      message: "Choose Google or GitHub to preview this form"
    }

    def preview
      valid?
      errors.add(:base, "Authentication is not connected in this foundation scaffold yet.")
      false
    end
  end
end
