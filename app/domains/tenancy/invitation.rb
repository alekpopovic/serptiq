# frozen_string_literal: true

module Tenancy
  class Invitation < ApplicationRecord
    self.table_name = "invitations"

    STATUSES = %w[pending accepted revoked expired superseded].freeze
    ROLE_KEYS = %w[organization_admin billing_admin seo_lead developer content_editor analyst viewer].freeze
    TOKEN_DIGEST_PATTERN = /\A[0-9a-f]{64}\z/

    belongs_to :organization, class_name: "Tenancy::Organization", inverse_of: :invitations
    belongs_to :invited_by_membership, class_name: "Tenancy::Membership", inverse_of: :sent_invitations
    belongs_to :accepted_by_membership, class_name: "Tenancy::Membership",
      inverse_of: :accepted_invitations, optional: true

    normalizes :email, with: ->(value) { value.to_s.strip.downcase }

    validates :email, presence: true, length: { maximum: 320 }, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :token_digest, presence: true, uniqueness: true, format: { with: TOKEN_DIGEST_PATTERN }
    validates :status, inclusion: { in: STATUSES }
    validates :expires_at, presence: true
    validates :email, uniqueness: { scope: :organization_id, conditions: -> { where(status: "pending") } },
      if: :pending?
    validate :expiry_is_bounded
    validate :lifecycle_is_consistent
    validate :initial_access_is_safe

    STATUSES.each { |candidate| define_method("#{candidate}?") { status == candidate } }

    private

    def expiry_is_bounded
      return if expires_at.nil? || created_at.nil?
      return if expires_at > created_at && expires_at <= created_at + 30.days

      errors.add(:expires_at, "must be within 30 days of creation")
    end

    def lifecycle_is_consistent
      timestamps = [ accepted_at, accepted_by_membership_id, revoked_at, expired_at, superseded_at ]
      valid = case status
      when "pending" then timestamps.all?(&:nil?)
      when "accepted" then accepted_at.present? && accepted_by_membership_id.present? && timestamps.drop(2).all?(&:nil?)
      when "revoked" then revoked_at.present? && [ accepted_at, accepted_by_membership_id, expired_at, superseded_at ].all?(&:nil?)
      when "expired" then expired_at.present? && [ accepted_at, accepted_by_membership_id, revoked_at, superseded_at ].all?(&:nil?)
      when "superseded" then superseded_at.present? && [ accepted_at, accepted_by_membership_id, revoked_at, expired_at ].all?(&:nil?)
      else false
      end
      errors.add(:status, "does not match lifecycle timestamps") unless valid
    end

    def initial_access_is_safe
      empty = initial_role_key.nil? && initial_scope_type.nil? && initial_scope_id.nil?
      valid = ROLE_KEYS.include?(initial_role_key) && initial_scope_type == "Organization" &&
        initial_scope_id == organization_id
      errors.add(:initial_role_key, "has an invalid organization scope") unless empty || valid
    end
  end
end
