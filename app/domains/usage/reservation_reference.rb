# frozen_string_literal: true

module Usage
  ReservationReference = Data.define(:id, :organization_id, :state, :held_quantity, :expires_at) do
    def initialize(**attributes)
      %i[id organization_id state].each do |name|
        attributes[name] = attributes.fetch(name).to_s.freeze
      end
      super(**attributes)
      freeze
    end

    def active_at?(at)
      state == "held" && expires_at > at
    end
  end
end
