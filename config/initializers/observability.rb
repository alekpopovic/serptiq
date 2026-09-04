# frozen_string_literal: true

require Rails.root.join("app/domains/shared/observability")
require Rails.root.join("app/domains/shared/observability/context")
require Rails.root.join("app/domains/shared/observability/request_context")

Rails.application.config.middleware.insert_after(
  ActionDispatch::RequestId,
  Shared::Observability::RequestContext
)
