# frozen_string_literal: true

module Properties
  IosConfiguration = Data.define(:bundle_id, :team_id) do
    BUNDLE_PATTERN = /\A[a-z][a-z0-9-]*(?:\.[a-z][a-z0-9-]*)+\z/
    TEAM_PATTERN = /\A[A-Z0-9]{10}\z/

    def initialize(bundle_id:, team_id:)
      normalized_bundle = bundle_id.to_s.strip.downcase
      normalized_team = team_id.to_s.strip.upcase
      raise ArgumentError, "iOS bundle identifier is invalid" unless BUNDLE_PATTERN.match?(normalized_bundle)
      raise ArgumentError, "Apple Team ID is invalid" unless TEAM_PATTERN.match?(normalized_team)

      super(bundle_id: normalized_bundle.freeze, team_id: normalized_team.freeze)
      freeze
    end

    def identifier
      "#{team_id}.#{bundle_id}"
    end

    def database_attributes
      { bundle_id: bundle_id, team_id: team_id }
    end
  end
end
