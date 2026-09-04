# frozen_string_literal: true

module Identity
  class GoogleOauthController < ApplicationController
    class_attribute :authorization_starter_factory,
      instance_accessor: false,
      default: -> { GoogleAuthorizationStarter.from_settings }
    class_attribute :callback_completer_factory,
      instance_accessor: false,
      default: -> { default_callback_completer }
    class_attribute :callback_rate_guard_factory,
      instance_accessor: false,
      default: -> { OauthCallbackRateGuard.from_settings }

    class << self
      def default_callback_completer
        @callback_completer_mutex ||= Mutex.new
        @callback_completer_mutex.synchronize do
          @default_callback_completer ||= GoogleCallbackCompleter.from_settings
        end
      end
    end

    before_action :set_sensitive_response_headers

    def create
      link_intent = parse_link_intent(params[:link])
      verify_link_confirmation!(params[:link_confirmation]) if link_intent
      start = self.class.authorization_starter_factory.call.call(
        return_to: SafeReturnPath.call(params[:return_to]),
        link_intent: link_intent,
        current_session: Current.session,
        initiator_digest: OauthInitiator.from_request(request).digest
      )
      # `redirect_to` publishes the complete destination to Rails redirect logs.
      # This trusted value contains one-time state/nonce query parameters, so set
      # the header directly after the adapter's exact-host validation.
      response.set_header("Location", start.authorization_request.to_s)
      head :see_other
    end

    def callback
      self.class.callback_rate_guard_factory.call.call(
        provider: "google",
        initiator_digest: OauthInitiator.from_request(request).digest
      ) do
        callback = GoogleCallbackParameters.from_query_string(request.query_string)
        completion = self.class.callback_completer_factory.call.call(
          callback: callback,
          current_session: Current.session
        )
        establish_identity_session!(
          completion.user,
          rotation_reason: completion.operation == "link" ? "privilege_changed" : "rotated"
        )
        redirect_to completion.return_to, status: :see_other, allow_other_host: false
      end
    end

    private

    def parse_link_intent(value)
      return false if value.nil? || value == false || value == "0"
      return true if value == true || value == "1"

      raise InvalidOauthInitiation
    end

    def verify_link_confirmation!(token)
      Public.verify_link_confirmation!(
        token: token,
        provider: "google",
        session: Current.session
      )
    end

    def set_sensitive_response_headers
      response.headers["Cache-Control"] = "no-store, max-age=0"
      response.headers["Pragma"] = "no-cache"
      response.headers["Expires"] = "0"
      response.headers["Referrer-Policy"] = "no-referrer"
      response.headers["X-Content-Type-Options"] = "nosniff"
      response.headers["X-Frame-Options"] = "DENY"
    end
  end
end
