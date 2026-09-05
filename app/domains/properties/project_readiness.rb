# frozen_string_literal: true

module Properties
  ProjectReadiness = Data.define(
    :project_id, :total_count, :active_count, :website_count,
    :verified_website_count, :active_environment_count, :primary_environment_count
  ) do
    def initialize(**attributes)
      attributes[:project_id] = attributes.fetch(:project_id).to_s.freeze
      %i[
        total_count active_count website_count verified_website_count
        active_environment_count primary_environment_count
      ].each { |name| attributes[name] = Integer(attributes.fetch(name)) }
      super(**attributes)
      freeze
    end

    def website_ready?
      website_count.positive?
    end

    def environment_ready?
      primary_environment_count.positive?
    end

    def verification_ready?
      verified_website_count.positive?
    end
  end
end
