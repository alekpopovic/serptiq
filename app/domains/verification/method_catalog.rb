# frozen_string_literal: true

module Verification
  module MethodCatalog
    LABELS = {
      "dns_txt" => "DNS TXT record",
      "html_file" => "HTML verification file",
      "meta_tag" => "HTML meta tag",
      "search_console" => "Google Search Console"
    }.freeze

    module_function

    def expected_location(method:, origin:)
      case method.to_s
      when "dns_txt" then "_searchops-verification.#{origin.host}"
      when "html_file" then "#{origin.origin}/.well-known/searchops-verification.txt"
      when "meta_tag" then "#{origin.origin}/"
      when "search_console" then origin.origin
      else raise ArgumentError, "unsupported verification method"
      end
    end

    def instructions(challenge)
      value = ChallengeToken.value_for(challenge)
      steps = case challenge.method
      when "dns_txt"
        [
          "Create a TXT record at the exact hostname below.",
          "Publish the exact value with unchanged case and whitespace, then retry. This challenge can be consumed only once."
        ]
      when "html_file"
        [
          "Serve a text/plain file at the exact HTTPS/HTTP location below.",
          "The complete response body must equal the exact value below, with no added whitespace or markup."
        ]
      when "meta_tag"
        [
          "Add exactly one verification tag to the static HTML <head> of the exact origin home page.",
          %(<meta name="searchops-verification" content="#{value}">),
          "JavaScript-generated tags are not executed or accepted."
        ]
      when "search_console"
        [ "This proof uses a separately consented Search Console connection, not your Google login session.",
          "Selected provider property: #{challenge.provider_property_identifier}",
          "Google-reported permission: #{challenge.provider_permission_level} (checked #{challenge.provider_checked_at.to_fs(:long)}).",
          "SearchOps rechecks the exact provider property before accepting this observed proof." ]
      end
      Instructions.new(
        method: challenge.method,
        label: LABELS.fetch(challenge.method),
        location: challenge.expected_location,
        value: value,
        steps: steps
      )
    end
  end
end
