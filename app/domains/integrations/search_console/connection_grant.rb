# frozen_string_literal: true

module Integrations
  module SearchConsole
    READONLY_SCOPE = "https://www.googleapis.com/auth/webmasters.readonly"
    CONSENT_KIND = "search_console_oauth"

    ConnectionGrant = Data.define(
      :external_account_id, :granted_scopes, :consented_at, :consent_reference, :consent_kind
    ) do
      def initialize(external_account_id:, granted_scopes:, consented_at:, consent_reference:,
        consent_kind: CONSENT_KIND)
        account = external_account_id.to_s
        scopes = Array(granted_scopes).map(&:to_s).uniq.sort.freeze
        reference = consent_reference.to_s
        valid_time = consented_at.is_a?(Time) || consented_at.is_a?(ActiveSupport::TimeWithZone)
        valid = account == account.strip && account.bytesize.between?(1, 255) &&
          scopes.include?(READONLY_SCOPE) && scopes.length <= 20 &&
          scopes.all? { |scope| scope == scope.strip && scope.bytesize.between?(1, 255) } &&
          reference.bytesize.between?(32, 512) && valid_time && consent_kind.to_s == CONSENT_KIND
        raise ArgumentError, "Search Console consent grant is invalid" unless valid

        super(
          external_account_id: account.freeze,
          granted_scopes: scopes,
          consented_at: consented_at,
          consent_reference: reference.freeze,
          consent_kind: CONSENT_KIND
        )
        freeze
      end
    end
  end
end
