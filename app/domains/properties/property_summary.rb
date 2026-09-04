# frozen_string_literal: true

module Properties
  PropertySummary = Data.define(
    :id, :project_id, :display_name, :kind, :status, :verification_status,
    :verified_at, :archived_at, :configuration
  ) do
    def initialize(**attributes)
      %i[id project_id display_name kind status verification_status].each do |name|
        attributes[name] = attributes.fetch(name).to_s.freeze
      end
      super(**attributes)
      freeze
    end

    def active?
      status == "active"
    end

    def archived?
      status == "archived"
    end

    def verified?
      verification_status == "verified"
    end

    def identifier
      configuration.identifier
    end
  end
end
