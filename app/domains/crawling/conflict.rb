# frozen_string_literal: true

module Crawling
  class Conflict < Shared::Public::ConflictError
    def initialize(reason_code: "crawl_policy_conflict")
      super(reason_code: reason_code)
    end
  end
end
