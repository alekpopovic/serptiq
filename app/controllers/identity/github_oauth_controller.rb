# frozen_string_literal: true

module Identity
  class GithubOauthController < ApplicationController
    class_attribute :authorization_starter_factory,
      instance_accessor: false,
      default: -> { GithubAuthorizationStarter.from_settings }
    class_attribute :callback_completer_factory,
      instance_accessor: false,
      default: -> { default_callback_completer }

    class << self
      def default_callback_completer
        @callback_completer_mutex ||= Mutex.new
        @callback_completer_mutex.synchronize do
          @default_callback_completer ||= GithubCallbackCompleter.from_settings
        end
      end
    end

    before_action :set_sensitive_response_headers

    def create
      start = self.class.authorization_starter_factory.call.call(
        return_to: SafeReturnPath.call(params[:return_to]),
        link_intent: parse_link_intent(params[:link]),
        current_session: Current.session,
        initiator_digest: OauthInitiator.from_request(request).digest
      )
      response.set_header("Location", start.authorization_request.to_s)
      head :see_other
    end

    def callback
      callback = GithubCallbackParameters.from_query_string(request.query_string)
      completion = self.class.callback_completer_factory.call.call(
        callback: callback,
        current_session: Current.session
      )
      establish_identity_session!(completion.user)
      redirect_to completion.return_to, status: :see_other, allow_other_host: false
    end

    private

    def parse_link_intent(value)
      return false if value.nil? || value == false || value == "0"
      return true if value == true || value == "1"

      raise InvalidOauthInitiation
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
