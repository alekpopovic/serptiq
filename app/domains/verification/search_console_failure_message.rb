# frozen_string_literal: true

module Verification
  module SearchConsoleFailureMessage
    MESSAGES = {
      "provider_scope_revoked" => "The Search Console connection needs authorization again.",
      "provider_property_inaccessible" => "The selected Search Console property is no longer accessible.",
      "provider_outage" => "Search Console is temporarily unavailable. Try again later.",
      "provider_ambiguous_match" => "Search Console returned an ambiguous duplicate property; reauthorize before retrying.",
      "provider_no_match" => "The selected Search Console property does not exactly cover this origin.",
      "provider_insufficient_permission" => "Google does not report verified owner permission for the selected property.",
      "provider_connection_changed" => "The Search Console account or authorization changed; select the property again.",
      "malformed_response" => "Search Console returned an unsupported property response."
    }.freeze

    module_function

    def for(category)
      MESSAGES.fetch(category.to_s, "Search Console did not confirm exact verified ownership.")
    end
  end
end
