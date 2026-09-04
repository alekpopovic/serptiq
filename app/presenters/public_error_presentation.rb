# frozen_string_literal: true

class PublicErrorPresentation
  Presentation = Data.define(:code, :title, :message, :action)

  class << self
    def call(error, mapping)
      details = identity_details(error)
      Presentation.new(
        code: mapping.public_code,
        title: details.fetch(:title),
        message: details.fetch(:message, mapping.public_message),
        action: details.fetch(:action)
      )
    end

    private

    def identity_details(error)
      case error
      when Tenancy::LastOwnerConflict
        {
          title: "Transfer ownership first",
          message: "The current owner cannot be suspended or removed. Transfer ownership to another active member, then try again.",
          action: :home
        }
      when Identity::ProviderError
        provider_details(error)
      when Identity::ExpiredOauthTransaction, Identity::ConsumedOauthTransaction,
        Identity::InvalidOauthTransaction
        {
          title: "This sign-in attempt is no longer valid",
          message: "Start sign-in again. Authorization attempts expire quickly and can be used only once.",
          action: :sign_in
        }
      when Identity::AccountLinkRequired
        {
          title: "Account confirmation is required",
          message: "Sign in with an identity already linked to your account, then use Account security to link another provider.",
          action: :sign_in
        }
      when Identity::RecentAuthenticationRequired
        {
          title: "Please authenticate again",
          message: "This security-sensitive action requires a recent sign-in.",
          action: :sign_in
        }
      when Identity::AuthenticationRateLimited, Identity::OauthInitiationLimited
        {
          title: "Please wait before trying again",
          action: :sign_in
        }
      when Shared::Public::QuotaError
        {
          title: "Usage limit reached",
          message: error.definition.public_message,
          action: :quota
        }
      else
        default_details(error)
      end
    end

    def provider_details(error)
      if error.category == "access_denied"
        {
          title: "Sign-in was cancelled",
          message: "No account change was made. You can start sign-in again when you are ready.",
          action: :sign_in
        }
      else
        {
          title: "Sign-in service is temporarily unavailable",
          message: "The external sign-in service could not complete the request. Wait a moment and try again.",
          action: :sign_in
        }
      end
    end

    def default_details(error)
      if error.is_a?(Shared::Public::ConflictError)
        {
          title: "This account action needs attention",
          message: "The request conflicts with the current account state. No identity or session was transferred.",
          action: :sign_in
        }
      elsif error.is_a?(Shared::Errors::InternalFault) || !error.is_a?(Shared::Errors::Base)
        {
          title: "Something went wrong",
          message: "Try again later. If the problem continues, share the Request ID with support.",
          action: :home
        }
      else
        { title: "We could not complete that request", action: :home }
      end
    end
  end
end
