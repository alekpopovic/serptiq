# frozen_string_literal: true

module Entitlements
  THREAD_KEY = :searchops_entitlement_catalog_syncing

  module_function

  def with_catalog_sync
    previous = Thread.current[THREAD_KEY]
    Thread.current[THREAD_KEY] = true
    yield
  ensure
    Thread.current[THREAD_KEY] = previous
  end

  def catalog_syncing?
    Thread.current[THREAD_KEY] == true
  end
end
