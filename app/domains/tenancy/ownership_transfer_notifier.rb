# frozen_string_literal: true

module Tenancy
  class OwnershipTransferNotifier
    EVENT_NAME = "ownership_transfer_notification.tenancy"

    def call(result)
      ActiveSupport::Notifications.instrument(
        EVENT_NAME,
        organization_id: result.organization.id,
        previous_owner_user_id: result.previous_owner.user_id,
        current_owner_user_id: result.current_owner.user_id
      )
      true
    rescue StandardError => error
      Shared::Public.report_observability_failure(error, event_name: EVENT_NAME)
      false
    end
  end
end
