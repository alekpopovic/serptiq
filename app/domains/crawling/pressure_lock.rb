# frozen_string_literal: true

module Crawling
  module PressureLock
    LOCK_NAME = "searchops:crawl-pressure:v1"

    module_function

    def acquire!(connection = ActiveRecord::Base.connection)
      connection.execute(
        "SELECT pg_advisory_xact_lock(hashtextextended(#{connection.quote(LOCK_NAME)}, 0))"
      )
    end
  end
end
