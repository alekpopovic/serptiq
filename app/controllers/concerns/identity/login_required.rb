# frozen_string_literal: true

module Identity
  module LoginRequired
    extend ActiveSupport::Concern

    included do
      before_action :require_authenticated_user
    end

    private

    def require_authenticated_user
      return if Current.user
      raise AuthenticationRequired if request.format.json?

      return_path = SafeReturnPath.call(request.fullpath)
      redirect_to sign_in_path(return_to: return_path), status: :found
    end
  end
end
