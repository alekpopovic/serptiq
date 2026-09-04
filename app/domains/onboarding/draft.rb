# frozen_string_literal: true

module Onboarding
  class Draft < ApplicationRecord
    self.table_name = "project_onboarding_drafts"

    STEPS = %w[project product property verification crawl review].freeze
    FLOW_TYPES = %w[website_only combined].freeze
    WEBSITE_KINDS = %w[website web_application].freeze
    VERIFICATION_METHODS = %w[dns_txt html_file meta_tag search_console].freeze
    QUERY_HANDLING = %w[ignore tracking_only all].freeze

    validates :organization_id, :actor_membership_id, :project_id, :website_property_id,
      :android_property_id, :ios_property_id, presence: true
    validates :project_release_key, format: { with: /\Aprj_[0-9a-f]{32}\z/ }
    validates :state, inclusion: { in: %w[draft completed] }
    validates :current_step, inclusion: { in: STEPS }
    validates :last_completed_step, inclusion: { in: STEPS }, allow_nil: true
    validates :flow_type, inclusion: { in: FLOW_TYPES }, allow_nil: true
    validates :website_kind, inclusion: { in: WEBSITE_KINDS }, allow_nil: true
    validates :verification_method, inclusion: { in: VERIFICATION_METHODS }, allow_nil: true
    validates :crawl_max_urls, numericality: { only_integer: true, in: 1..200_000 }
    validates :crawl_max_depth, numericality: { only_integer: true, in: 0..20 }
    validates :crawl_query_handling, inclusion: { in: QUERY_HANDLING }
    validate :lifecycle_shape

    scope :active, -> { where(state: "draft") }

    def draft?
      state == "draft" && completed_at.nil?
    end

    def completed?
      state == "completed" && completed_at.present?
    end

    def previous_step
      index = STEPS.index(current_step)
      index&.positive? ? STEPS.fetch(index - 1) : nil
    end

    def next_step
      index = STEPS.index(current_step)
      index && index < STEPS.length - 1 ? STEPS.fetch(index + 1) : nil
    end

    private

    def lifecycle_shape
      errors.add(:state, "does not match completion timestamp") unless draft? || completed?
    end
  end
end
