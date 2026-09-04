# frozen_string_literal: true

module Properties
  EnvironmentSummary = Data.define(
    :id, :property_id, :key, :kind, :display_name, :primary, :status, :archived_at, :origin
  ) do
    def initialize(**attributes)
      %i[id property_id key kind display_name status].each do |name|
        attributes[name] = attributes.fetch(name).to_s.freeze
      end
      attributes[:primary] = !!attributes.fetch(:primary)
      super(**attributes)
      freeze
    end

    def active?
      status == "active"
    end

    def archived?
      status == "archived"
    end

    def primary?
      primary
    end
  end
end
