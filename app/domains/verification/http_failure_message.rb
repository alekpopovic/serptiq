# frozen_string_literal: true

module Verification
  module HttpFailureMessage
    MESSAGES = {
      "unsafe_destination" => "Verification stopped because the destination did not pass the public-network safety policy.",
      "http_dns_failure" => "The verification hostname could not be resolved safely. Retry after DNS has recovered.",
      "http_timeout" => "The bounded HTTP request timed out. Retry after the site has recovered.",
      "http_transport_failure" => "The verification page could not be reached. No ownership conclusion was made.",
      "http_redirect_rejected" => "The site redirected outside the explicitly allowed canonical hostname variants.",
      "http_redirect_limit" => "The verification request exceeded the redirect safety limit.",
      "http_response_too_large" => "The verification response exceeded the safety size limit.",
      "http_content_type_rejected" => "The verification response used an unsupported content type.",
      "malformed_response" => "The verification response could not be parsed safely.",
      "duplicate_meta" => "More than one verification meta tag was found; keep exactly one tag with the exact value.",
      "proof_mismatch" => "The verification page was found, but its value did not exactly match this challenge.",
      "proof_missing" => "The exact verification value was not present at the required path."
    }.freeze

    module_function

    def for(category)
      MESSAGES.fetch(category.to_s, "Proof was not observed yet. Check the exact instructions before retrying.")
    end
  end
end
