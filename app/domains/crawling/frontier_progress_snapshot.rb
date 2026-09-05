# frozen_string_literal: true

module Crawling
  FrontierProgressSnapshot = Data.define(:scan_id, :status, *ScanCounters.members, :observed_at) do
    def initialize(**attributes)
      attributes[:scan_id] = attributes.fetch(:scan_id).to_s.freeze
      attributes[:status] = attributes.fetch(:status).to_s.freeze
      ScanCounters.members.each do |name|
        attributes[name] = Integer(attributes.fetch(name))
      end
      super(**attributes)
      freeze
    end
  end
end
