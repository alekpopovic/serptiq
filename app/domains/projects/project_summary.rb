# frozen_string_literal: true

module Projects
  ProjectSummary = Data.define(
    :id, :slug, :name, :description, :status, :default_locale, :time_zone,
    :external_release_key, :archived_at, :deletion_requested_at, :health_state,
    :property_count, :latest_scan_state, :latest_scan_at
  ) do
    def initialize(**attributes)
      %i[id slug name description status default_locale time_zone external_release_key health_state
        latest_scan_state].each do |name|
        attributes[name] = attributes.fetch(name).to_s.freeze
      end
      attributes[:property_count] = Integer(attributes.fetch(:property_count))
      super(**attributes)
      freeze
    end

    def active?
      status == "active"
    end

    def archived?
      status == "archived"
    end

    def pending_deletion?
      status == "pending_deletion"
    end

    def scan_available?
      active?
    end
  end
end
