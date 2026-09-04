# frozen_string_literal: true

module Tenancy
  OrganizationNavigationEntry = Data.define(:id, :name, :slug, :status) do
    LABELS = {
      "active" => "Active",
      "suspended" => "Suspended",
      "pending_deletion" => "Deletion pending"
    }.freeze

    def initialize(id:, name:, slug:, status:)
      raise ArgumentError, "unsupported organization navigation status" unless LABELS.key?(status)

      super(id: id.to_s.freeze, name: name.to_s.freeze, slug: slug.to_s.freeze, status: status.freeze)
      freeze
    end

    def available?
      status == "active"
    end

    def status_label
      LABELS.fetch(status)
    end
  end
end
