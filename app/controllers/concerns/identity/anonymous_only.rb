# frozen_string_literal: true

module Identity
  module AnonymousOnly
    extend ActiveSupport::Concern

    class_methods do
      def anonymous_only(**options)
        before_action :require_anonymous_user, **options
      end
    end

    private

    def require_anonymous_user
      return unless Current.user

      redirect_to SafeReturnPath.call(params[:return_to]), status: :see_other
    end
  end
end
