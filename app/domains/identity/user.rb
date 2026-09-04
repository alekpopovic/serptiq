# frozen_string_literal: true

module Identity
  class User < ApplicationRecord
    self.table_name = "users"

    has_many :sessions,
      class_name: "Identity::Session",
      inverse_of: :user,
      dependent: :restrict_with_exception

    normalizes :primary_email, with: ->(value) { value.to_s.strip.downcase.presence }

    validates :primary_email,
      format: { with: URI::MailTo::EMAIL_REGEXP },
      length: { maximum: 320 },
      allow_nil: true
    validates :display_name, length: { maximum: 160 }, allow_nil: true
    validates :avatar_url, length: { maximum: 2048 }, allow_nil: true
    validates :locale, presence: true, length: { maximum: 16 }
    validates :time_zone, presence: true, length: { maximum: 64 }

    def active?
      suspended_at.nil? && deleted_at.nil?
    end
  end
end
