# frozen_string_literal: true

module Identity
  class AccountSecurityController < ApplicationController
    include LoginRequired

    class_attribute :rate_limiter_factory,
      instance_accessor: false,
      default: -> { AuthenticationRateLimiter.from_settings }

    layout "authenticated"
    before_action :set_no_store_headers
    before_action :rate_limit_sensitive_action, only: %i[confirm_link destroy]

    def show
      @active_identities = Current.user.provider_identities.where(revoked_at: nil).order(:provider, :created_at)
      @linked_providers = @active_identities.index_by(&:provider)
    end

    def confirm_link
      @provider = provider_from_path!
      if Current.user.provider_identities.where(provider: @provider, revoked_at: nil).exists?
        raise InvalidAccountLink.new(reason_code: "provider_already_linked")
      end

      @link_confirmation = Public.issue_link_confirmation!(provider: @provider, session: Current.session)
    end

    def destroy
      result = Public.unlink_provider_identity!(
        identity_id: params[:id],
        current_session: Current.session,
        metadata: SessionMetadata.from_request(request)
      )
      accept_issued_identity_session!(result.issued_session)
      redirect_to account_security_path,
        status: :see_other,
        notice: "#{provider_label(result.provider)} has been unlinked. Your session was rotated."
    end

    private

    def rate_limit_sensitive_action
      self.class.rate_limiter_factory.call.consume!(
        scope: "account_security_session",
        key: Current.session.id
      )
    end

    def provider_from_path!
      provider = params[:provider].to_s.downcase
      return provider if ProviderIdentity::PROVIDERS.include?(provider)

      raise InvalidAccountLink.new(reason_code: "account_link_provider_invalid")
    end

    def provider_label(provider)
      provider == "github" ? "GitHub" : provider.capitalize
    end

    def set_no_store_headers
      response.headers["Cache-Control"] = "no-store, max-age=0"
      response.headers["Pragma"] = "no-cache"
      response.headers["Referrer-Policy"] = "no-referrer"
    end
  end
end
