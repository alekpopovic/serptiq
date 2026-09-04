# frozen_string_literal: true

module Billing
  class SubscriptionStatusQuery
    def call(organization_id:, at: Time.current)
      return unless Shared::Public.application_uuid?(organization_id)

      subscription = Subscription.where(organization_id: organization_id)
        .order(started_at: :desc, created_at: :desc).first
      return unless subscription

      access = subscription.effective_access_state(at: at)
      label, message, remediation, effective_at = presentation(subscription, access)
      SubscriptionStatus.new(
        subscription_id: subscription.id,
        status: subscription.status,
        access_state: access,
        label: label,
        message: message,
        remediation: remediation,
        effective_at: effective_at,
        provider_reported_at: subscription.provider_updated_at,
        plan_change: SubscriptionChange.active.find_by(subscription_id: subscription.id)&.summary
      )
    end

    private

    def presentation(subscription, access)
      case subscription.status
      when "trialing"
        [ "Trial active", "Current plan access is available during the confirmed trial period.", nil,
          subscription.trial_ends_at ]
      when "active"
        [ "Billing active", "Current plan access follows the latest confirmed local billing record.", nil, nil ]
      when "past_due"
        past_due_presentation(subscription, access)
      when "paused"
        [ "Billing paused", "Existing data remains available according to read-only policy; new work is paused.",
          "Review payment and subscription settings in the billing provider portal.", nil ]
      when "canceled"
        [ "Cancellation scheduled", cancellation_message(subscription, access),
          "Use the billing provider portal to reverse or update the cancellation.", subscription.access_expires_at ]
      when "expired"
        [ "Subscription expired", "Existing data remains available according to retention and read-only policy.",
          "Review available plans or billing settings to restore new work.", subscription.ended_at ]
      else
        [ "Billing setup incomplete", "Paid-plan access is not active yet.",
          "Complete or review billing setup in the billing provider portal.", nil ]
      end
    end

    def past_due_presentation(subscription, access)
      if access == "grace"
        [ "Payment needs attention", "Existing access is temporarily available during the local grace policy.",
          "Review payment details in the billing provider portal.", subscription.grace_ends_at ]
      else
        [ "Payment overdue", "Existing data remains readable, but new scheduled and billable work is paused.",
          "Resolve payment in the billing provider portal to restore new work.", subscription.grace_ends_at ]
      end
    end

    def cancellation_message(subscription, access)
      return "Current access remains available until the confirmed effective end." if access == "full"

      "The confirmed access period has ended; existing data remains subject to read-only policy."
    end
  end
end
