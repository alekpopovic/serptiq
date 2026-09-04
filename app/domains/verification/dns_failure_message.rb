# frozen_string_literal: true

module Verification
  module DnsFailureMessage
    MESSAGES = {
      "dns_nxdomain" => "The resolver observed NXDOMAIN for the exact verification hostname.",
      "dns_no_record" => "The hostname resolved, but no TXT record was observed.",
      "dns_propagating" => "A TXT response was observed, but the exact value is not visible yet; propagation is a temporary heuristic, not a guarantee.",
      "dns_timeout" => "The bounded DNS lookup timed out. Retry after the resolver has recovered.",
      "dns_transient_failure" => "The DNS resolver had a transient failure. No ownership conclusion was made.",
      "dns_multiple_records" => "Multiple TXT records were observed without one unambiguous exact proof value.",
      "dns_response_limit" => "The DNS response exceeded the verification safety limit.",
      "dns_cname_limit" => "The CNAME chain exceeded the verification safety limit.",
      "dns_delegation_limit" => "The DNS delegation response exceeded the verification safety limit.",
      "proof_mismatch" => "A TXT value was observed, but it did not exactly match this challenge."
    }.freeze

    module_function

    def for(category)
      MESSAGES.fetch(category.to_s, "Proof was not observed yet. Check the exact instructions before retrying.")
    end
  end
end
