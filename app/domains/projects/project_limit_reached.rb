# frozen_string_literal: true

module Projects
  class ProjectLimitReached < Shared::Public::QuotaError
    attr_reader :limit, :active_count

    def initialize(limit:, active_count:)
      @limit = limit
      @active_count = active_count
      super(reason_code: "project_limit_reached")
    end
  end
end
