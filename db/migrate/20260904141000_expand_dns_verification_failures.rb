# frozen_string_literal: true

class ExpandDnsVerificationFailures < ActiveRecord::Migration[8.1]
  FAILURE_CATEGORIES = %w[
    proof_missing proof_mismatch provider_unavailable provider_unauthorized unsafe_destination
    malformed_response attempt_limit dns_nxdomain dns_no_record dns_propagating dns_timeout
    dns_transient_failure dns_multiple_records dns_response_limit dns_cname_limit dns_delegation_limit
  ].freeze

  def up
    remove_check_constraint :domain_verifications,
      name: "domain_verifications_failure_category_allowlist", if_exists: true
    remove_check_constraint :domain_verification_attempts,
      name: "domain_verification_attempts_failure_category_allowlist", if_exists: true

    add_failure_constraint(:domain_verifications, "domain_verifications_failure_category_allowlist")
    add_failure_constraint(
      :domain_verification_attempts, "domain_verification_attempts_failure_category_allowlist"
    )
  end

  def down
    remove_check_constraint :domain_verifications,
      name: "domain_verifications_failure_category_allowlist"
    remove_check_constraint :domain_verification_attempts,
      name: "domain_verification_attempts_failure_category_allowlist"
  end

  private

  def add_failure_constraint(table, name)
    allowed = FAILURE_CATEGORIES.map { |category| connection.quote(category) }.join(", ")
    add_check_constraint table, "failure_category IS NULL OR failure_category IN (#{allowed})",
      name: name, validate: false
    validate_check_constraint table, name: name
  end
end
