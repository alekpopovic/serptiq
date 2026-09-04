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
        [ "Serve a plain-text file at the exact HTTPS/HTTP location below.", "The response body must equal the exact value below." ]
      when "meta_tag"
        [ "Add this tag inside the <head> of the exact origin home page.",
          %(<meta name="searchops-verification" content="#{value}">) ]
      when "search_console"
        [ "Connect a Search Console account with verified ownership.",
          "The adapter must confirm an exact property match for the origin below." ]
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
