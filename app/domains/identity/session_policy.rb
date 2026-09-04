# frozen_string_literal: true

module Identity
  module SessionPolicy
    ABSOLUTE_LIFETIME = 30.days
    IDLE_TIMEOUT = 24.hours
    LAST_SEEN_WRITE_INTERVAL = 5.minutes
  end
end
