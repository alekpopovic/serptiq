# frozen_string_literal: true

class ExpandHttpVerificationFailures < ActiveRecord::Migration[8.1]
  DNS_CATEGORIES = %w[
    proof_missing proof_mismatch provider_unavailable provider_unauthorized unsafe_destination
    malformed_response attempt_limit dns_nxdomain dns_no_record dns_propagating dns_timeout
    dns_transient_failure dns_multiple_records dns_response_limit dns_cname_limit dns_delegation_limit
  ].freeze
  HTTP_CATEGORIES = %w[
    http_dns_failure http_timeout http_transport_failure http_redirect_rejected http_redirect_limit
    http_response_too_large http_content_type_rejected duplicate_meta
  ].freeze
  CONSTRAINTS = {
    domain_verifications: "domain_verifications_failure_category_allowlist",
    domain_verification_attempts: "domain_verification_attempts_failure_category_allowlist"
  }.freeze

  def up
    replace_constraints(DNS_CATEGORIES + HTTP_CATEGORIES)
  end

  def down
    replace_constraints(DNS_CATEGORIES)
  end

  private

  def replace_constraints(categories)
    allowed = categories.map { |category| connection.quote(category) }.join(", ")
    CONSTRAINTS.each do |table, name|
      remove_check_constraint table, name: name
      add_check_constraint table, "failure_category IS NULL OR failure_category IN (#{allowed})",
        name: name, validate: false
      validate_check_constraint table, name: name
    end
  end
end
