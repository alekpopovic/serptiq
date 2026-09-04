# frozen_string_literal: true

module Identity
  class User < ApplicationRecord
    self.table_name = "users"

    has_many :sessions,
      class_name: "Identity::Session",
      inverse_of: :user,
      dependent: :restrict_with_exception
    has_many :provider_identities,
      class_name: "Identity::ProviderIdentity",
      inverse_of: :user,
      dependent: :restrict_with_exception

    normalizes :primary_email, with: ->(value) { value.to_s.strip.downcase.presence }

    validates :primary_email,
      format: { with: URI::MailTo::EMAIL_REGEXP },
      length: { maximum: 320 },
      allow_nil: true
    validates :primary_email,
      uniqueness: { conditions: -> { where(deleted_at: nil) }, case_sensitive: false },
      allow_nil: true
    validates :display_name, length: { maximum: 160 }, allow_nil: true
    validates :avatar_url, length: { maximum: 2048 }, allow_nil: true
    validates :locale, inclusion: { in: I18n.available_locales.map(&:to_s) }, length: { maximum: 16 }
    validates :time_zone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }, length: { maximum: 64 }

    def active?
      suspended_at.nil? && deleted_at.nil?
    end
  end
end
