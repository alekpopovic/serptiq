# frozen_string_literal: true

module Auditing
  class AuthorizeAccess
    def call(organization_id:, authorization:, permission_key:)
      valid = authorization&.respond_to?(:allow?) && authorization.allow? &&
        authorization.respond_to?(:permission_key) && authorization.permission_key == permission_key &&
        authorization.respond_to?(:organization_id) && authorization.organization_id.to_s == organization_id.to_s &&
        authorization.respond_to?(:scope_type) && authorization.scope_type == "Organization" &&
        authorization.respond_to?(:scope_id) && authorization.scope_id.to_s == organization_id.to_s
      raise AccessDenied unless valid

      true
    end
  end
end
